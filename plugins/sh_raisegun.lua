--- Raise Weapon keeps weapons lowered until the player raises them by holding the reload key
-- for a second.
-- Holding the key again lowers the weapon, and so does switching weapons. A lowered weapon
-- cannot fire and is held in a lowered pose; the physgun, gravity gun, tool gun and camera
-- always count as raised. The state is read and changed with `Player:is_weapon_raised`,
-- `Player:set_weapon_raised` and `Player:toggle_weapon_raised`, and plugins take part through
-- the `CanPlayerRaiseWeapon`, `ShouldWeaponBeRaised`, `OnWeaponRaised`, `WeaponRaised`,
-- `WeaponLowered`, `CanPlayerAttack` and `AdjustWeaponLoweredView` hooks.
--
-- A weapon can fix its own state and its lowered pose with fields, which are read from the
-- item that gives the weapon (the item template whose `weapon_class` is the class of the
-- weapon) and, where the item does not set them, from the weapon itself:
-- ```
-- -- In an item file. The weapon is held in the lowered pose and cannot be raised, but it
-- -- can still be used.
-- ITEM.never_raised = true
-- -- The weapon cannot be lowered, like the physgun.
-- ITEM.always_raised = true
-- -- The lowered pose: how far the view model is turned and moved.
-- ITEM.lowered_angles = Angle(0, 45, 0)
-- ITEM.lowered_origin = Vector(3, 0, -4)
--
-- -- The same in a scripted weapon.
-- SWEP.NeverRaised = true
-- SWEP.AlwaysRaised = true
-- SWEP.LoweredAngles = Angle(0, 45, 0)
-- SWEP.LoweredOrigin = Vector(3, 0, -4)
-- ```
-- The angles turn the view model around its up (pitch field), forward (yaw field) and right
-- (roll field) axes, and the origin moves it to the right (x), forward (y) and up (z).
--
-- The plugin has three configs, whose defaults leave it working the way it does without
-- them: `weapon_raise_enabled` turns the lowering of weapons off altogether,
-- `sprint_lowers_weapon` lowers the weapon of a running player, and `weapon_raise_fire_delay`
-- is the time a weapon cannot fire for after it has been raised.
-- @module [PLUGIN]

PLUGIN:set_name('Raise Weapon')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Allows weapons to be lowered and raised by holding the R key.')

BOOL_WEAPON_RAISED = 1

if !Config.get_definition('weapon_raise_enabled') then
  Config.read({
    categories = {
      weapon_raise = {
        name = 'config.weapon_raise.title',
        description = 'config.weapon_raise.desc'
      }
    },
    configs = {
      weapon_raise_enabled = {
        name = 'config.weapon_raise.enabled.name',
        description = 'config.weapon_raise.enabled.desc',
        category = 'weapon_raise',
        type = 'boolean',
        default_value = true
      },
      sprint_lowers_weapon = {
        name = 'config.weapon_raise.sprint_lowers_weapon.name',
        description = 'config.weapon_raise.sprint_lowers_weapon.desc',
        category = 'weapon_raise',
        type = 'boolean',
        default_value = false
      },
      weapon_raise_fire_delay = {
        name = 'config.weapon_raise.fire_delay.name',
        description = 'config.weapon_raise.fire_delay.desc',
        category = 'weapon_raise',
        type = 'number',
        min_value = 0,
        max_value = 10,
        decimals = 1,
        default_value = 0
      }
    }
  })
end

Flux.Lang:add('en', {
  config = {
    weapon_raise = {
      title = 'Weapon Raising',
      desc = 'Settings for lowering and raising weapons.',
      enabled = {
        name = 'Weapon Raising System',
        desc = 'Whether weapons stay lowered until the player raises them by holding the reload key. '
          ..'When disabled, weapons are raised unless something else keeps them lowered.'
      },
      sprint_lowers_weapon = {
        name = 'Sprinting Lowers Weapon',
        desc = 'Whether the weapon of a running player is lowered and cannot fire until they slow down.'
      },
      fire_delay = {
        name = 'Fire Delay After Raising',
        desc = 'How many seconds a weapon cannot fire for after it has been raised. Set to 0 to disable.'
      }
    }
  }
})

Flux.Lang:add('ru', {
  config = {
    weapon_raise = {
      title = 'Поднятие оружия',
      desc = 'Настройки опускания и поднятия оружия.',
      enabled = {
        name = 'Система поднятия оружия',
        desc = 'Остается ли оружие опущенным, пока игрок не поднимет его, удерживая клавишу перезарядки. '
          ..'Если выключено, оружие поднято, пока что-либо другое не заставит его опустить.'
      },
      sprint_lowers_weapon = {
        name = 'Бег опускает оружие',
        desc = 'Опускается ли оружие бегущего игрока. Стрелять из него нельзя, пока игрок не замедлится.'
      },
      fire_delay = {
        name = 'Задержка стрельбы после поднятия',
        desc = 'Сколько секунд после поднятия оружия из него нельзя стрелять. Установите 0, чтобы отключить.'
      }
    }
  }
})

local rotation_translate = {
  ['default'] = Angle(30, -30, -25),
  ['weapon_fists'] = Angle(30, -30, -50)
}

local blocked_weapons = {
  ['weapon_physgun'] = true,
  ['gmod_tool'] = true,
  ['gmod_camera'] = true,
  ['weapon_physcannon'] = true
}

local weapon_items = {}

--- Finds the item that gives a weapon: the item template whose `weapon_class` is the class
-- of the weapon. Base items are skipped, and of several items that give the same weapon the
-- one whose ID comes first alphabetically is taken, so that the server and the clients agree.
-- The answer is remembered for every class until the schema is loaded again.
-- @param class [String weapon class]
-- @return [Item item template, or nil if no item gives the weapon or the items plugin is not
--   loaded]
local function find_weapon_item(class)
  local cached = weapon_items[class]

  if cached != nil then
    return cached or nil
  end

  local found = false

  if Item then
    for id, item_obj in pairs(Item.all()) do
      if item_obj.weapon_class == class and !item_obj.is_base
      and (!found or tostring(id) < tostring(found.id)) then
        found = item_obj
      end
    end
  end

  weapon_items[class] = found

  return found or nil
end

--- Reads one of the raise settings of a weapon: from the item that gives the weapon if the
-- item sets it, from the weapon itself otherwise.
-- @param weapon [Weapon]
-- @param class [String class of the weapon]
-- @param item_key [String name of the field of the item, e.g. 'never_raised']
-- @param weapon_key [String name of the field of the weapon, e.g. 'NeverRaised']
-- @return [Any value of the field, nil if neither the item nor the weapon sets it]
local function weapon_option(weapon, class, item_key, weapon_key)
  local item_obj = find_weapon_item(class)

  if item_obj and item_obj[item_key] != nil then
    return item_obj[item_key]
  end

  return weapon[weapon_key]
end

--- Tells whether the raised state of a weapon is fixed by the weapon itself.
-- The physgun, gravity gun, tool gun and camera are always raised, and so is a weapon with
-- the `always_raised` item field or the `AlwaysRaised` weapon field. A weapon with the
-- `never_raised` item field or the `NeverRaised` weapon field is never raised.
-- @param weapon [Weapon]
-- @return [Boolean true if the weapon is always raised, false if it is never raised, nil if
--   it can be raised and lowered]
local function fixed_raise_state(weapon)
  local class = weapon:GetClass()

  if blocked_weapons[class] or weapon_option(weapon, class, 'always_raised', 'AlwaysRaised') then
    return true
  end

  if weapon_option(weapon, class, 'never_raised', 'NeverRaised') then
    return false
  end
end

--- Returns the time a weapon that has just been raised cannot fire for.
-- @return [Number seconds from the `weapon_raise_fire_delay` config; 0 while the
--   `weapon_raise_enabled` config is off]
local function raise_fire_delay()
  if !Config.get('weapon_raise_enabled', true) then
    return 0
  end

  return Config.get('weapon_raise_fire_delay', 0)
end

--- Keeps a weapon from firing for the next 60 seconds and marks it as blocked by the plugin.
-- @param weapon [Weapon]
-- @param cur_time [Number CurTime() of the call]
local function block_fire(weapon, cur_time)
  weapon:SetNextPrimaryFire(cur_time + 60)
  weapon:SetNextSecondaryFire(cur_time + 60)

  weapon.fl_fire_blocked = true
end

--- Lets a weapon fire again from the given time on and clears the mark left by block_fire.
-- @param weapon [Weapon]
-- @param next_fire [Number CurTime() based time of the first shot that is allowed]
local function release_fire(weapon, next_fire)
  weapon:SetNextPrimaryFire(next_fire)
  weapon:SetNextSecondaryFire(next_fire)

  weapon.fl_fire_blocked = nil
end

if CLIENT then
  --- Works out the lowered pose of a weapon: how far its view model is turned and moved
  -- when the weapon is fully lowered.
  -- The angles come from the `lowered_angles` field of the item that gives the weapon, the
  -- `LoweredAngles` field of the weapon or the defaults of the plugin, the origin from
  -- `lowered_origin`, `LoweredOrigin` or no offset. The AdjustWeaponLoweredView hook can
  -- replace either.
  -- @param weapon [Weapon]
  -- @return [Angle rotation around the up (pitch field), forward (yaw field) and right (roll
  --   field) axes of the view, Vector offset to the right (x), forward (y) and up (z)]
  local function lowered_view(weapon)
    local class = weapon:GetClass()
    local item_obj = find_weapon_item(class)
    local angles = weapon_option(weapon, class, 'lowered_angles', 'LoweredAngles')
      or rotation_translate[class] or rotation_translate['default']
    local origin = weapon_option(weapon, class, 'lowered_origin', 'LoweredOrigin') or vector_origin

    --- Lets plugins change the lowered pose of a weapon.
    -- Called on the client on every frame the view model of the local player's weapon is
    -- positioned, whether the weapon is lowered at that moment or not. The angles and the
    -- origin that are passed in are shared between calls: return new ones rather than
    -- changing them.
    -- @param weapon [Weapon The active weapon of the local player]
    -- @param angles [Angle How far the lowered view model is turned around the up (pitch
    --   field), forward (yaw field) and right (roll field) axes of the view]
    -- @param origin [Vector How far the lowered view model is moved to the right (x), forward
    --   (y) and up (z)]
    -- @param item_obj [Item Template of the item that gives the weapon, nil if there is none]
    -- @return [Angle Angles to use instead, Vector Origin to use instead. The origin can be left
    --   out to keep it; a handler that only changes the origin has to return the angles it
    --   was given in front of it, since a nil first value counts as no answer]
    local new_angles, new_origin = hook.Run('AdjustWeaponLoweredView', weapon, angles, origin, item_obj)

    return new_angles or angles, new_origin or origin
  end

  --- Turns and moves the view model into the lowered pose while the local player's weapon is
  -- not raised, then lets the weapon's GetViewModelPosition and CalcViewModelView adjust it.
  -- @param weapon [Weapon]
  -- @param view_model [Entity]
  -- @param old_eye_pos [Vector]
  -- @param old_eye_angles [Angle]
  -- @param eye_pos [Vector]
  -- @param eye_angles [Angle]
  -- @return [Vector view model position, Angle view model angles; nothing if the weapon
  --   is not valid]
  function PLUGIN:CalcViewModelView(weapon, view_model, old_eye_pos, old_eye_angles, eye_pos, eye_angles)
    if !IsValid(weapon) then
      return
    end

    local target_val = 0

    if !PLAYER:is_weapon_raised() then
      target_val = 100
    end

    local fraction = (PLAYER.curRaisedFrac or 0) / 100
    local rotation, origin = lowered_view(weapon)

    eye_angles:RotateAroundAxis(eye_angles:Up(), rotation.p * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Forward(), rotation.y * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Right(), rotation.r * fraction)

    local offset = (
      eye_angles:Right() * origin.x + eye_angles:Forward() * origin.y + eye_angles:Up() * origin.z
    ) * fraction

    PLAYER.curRaisedFrac = Lerp(FrameTime() * 2, PLAYER.curRaisedFrac or 0, target_val)

    view_model:SetAngles(eye_angles)

    if weapon.GetViewModelPosition then
      local position, angles = weapon:GetViewModelPosition(eye_pos, eye_angles)

      old_eye_pos = position or old_eye_pos
      eye_angles = angles or eye_angles
    end

    if weapon.CalcViewModelView then
      local position, angles = weapon:CalcViewModelView(view_model, old_eye_pos, old_eye_angles, eye_pos, eye_angles)

      old_eye_pos = position or old_eye_pos
      eye_angles = angles or eye_angles
    end

    return old_eye_pos + offset, eye_angles
  end

  --- Removes the attack keys from the command when the CanPlayerAttack hook returns false.
  -- @param actor [Player]
  -- @param user_cmd [CUserCmd]
  function PLUGIN:StartCommand(actor, user_cmd)
    --- Asks whether the local player may attack.
    -- Called on the client for every user command that is built; the plugin's own handler
    -- denies it while the weapon is lowered.
    -- @return [Boolean Return false to strip the primary and secondary attack keys from the
    --   command]
    if hook.Run('CanPlayerAttack') == false then
      user_cmd:RemoveKey(IN_ATTACK + IN_ATTACK2)
    end
  end

  --- Prevents the local player from attacking while their weapon is lowered, unless it is a
  -- weapon that is never raised: such a weapon is used in the lowered pose.
  -- @return [Boolean false if the weapon is lowered, nil otherwise]
  function PLUGIN:CanPlayerAttack()
    if !PLAYER:is_weapon_raised() then
      local weapon = PLAYER:GetActiveWeapon()

      if !IsValid(weapon) or fixed_raise_state(weapon) != false then
        return false
      end
    end
  end
end

--- Forgets which items give which weapons, so that they are looked up again among the items
-- of the schema and the plugins that have just been loaded.
function PLUGIN:OnSchemaLoaded()
  weapon_items = {}
end

--- Starts a one second timer that toggles the player's weapon raise when reload is pressed.
-- Does nothing while the `weapon_raise_enabled` config is off.
-- @param actor [Player]
-- @param key [Number IN_ enum of the pressed key]
function PLUGIN:KeyPress(actor, key)
  if key == IN_RELOAD and Config.get('weapon_raise_enabled', true) then
    timer.Create('fl_weapon_raise_'..actor:SteamID(), 1, 1, function()
      if IsValid(actor) then
        actor:toggle_weapon_raised()
      end
    end)
  end
end

--- Cancels the pending weapon raise toggle when reload is released.
-- @param actor [Player]
-- @param key [Number IN_ enum of the released key]
function PLUGIN:KeyRelease(actor, key)
  if key == IN_RELOAD then
    timer.Remove('fl_weapon_raise_'..actor:SteamID())
  end
end

--- Lowers the player's weapon whenever they switch weapons.
-- @param actor [Player]
-- @param old_weapon [Weapon]
-- @param new_weapon [Weapon]
function PLUGIN:PlayerSwitchWeapon(actor, old_weapon, new_weapon)
  actor:set_weapon_raised(false)
end

--- Runs the UpdateWeaponRaised hook with the current time if the weapon is valid.
-- @param actor [Player]
-- @param weapon [Weapon the player's active weapon]
-- @param raised [Boolean whether the weapon is now raised]
function PLUGIN:OnWeaponRaised(actor, weapon, raised)
  if IsValid(weapon) then
    --- Called on the server when the raised state of a player's valid weapon has been set.
    -- The plugin's own handler lets the weapon fire or blocks its fire, then runs
    -- `WeaponRaised` or `WeaponLowered`.
    -- @param actor [Player The player holding the weapon]
    -- @param weapon [Weapon The active weapon of the player]
    -- @param raised [Boolean Whether the weapon is now raised]
    -- @param cur_time [Number CurTime() of the change]
    hook.Run('UpdateWeaponRaised', actor, weapon, raised, CurTime())
  end
end

--- Lets the weapon fire again (raised, or a weapon that cannot be lowered) or blocks its
-- fire for 60 seconds (lowered). Then calls the weapon's OnRaised or OnLowered method and
-- runs the WeaponRaised or WeaponLowered hook.
-- A weapon that has just been raised can fire once the `weapon_raise_fire_delay` config has
-- passed; a weapon that cannot be lowered can fire at once. A weapon that has been raised
-- while something else still keeps it lowered (the player is running and the
-- `sprint_lowers_weapon` config is on, or a ShouldWeaponBeRaised handler holds it down) stays
-- blocked, and PlayerThink lets it fire once that is over. The fire of a weapon that is
-- never raised is not blocked when it is lowered.
-- @param actor [Player]
-- @param weapon [Weapon]
-- @param raised [Boolean whether the weapon is now raised]
-- @param cur_time [Number CurTime() of the change]
function PLUGIN:UpdateWeaponRaised(actor, weapon, raised, cur_time)
  local fixed_state = fixed_raise_state(weapon)

  if raised or fixed_state == true then
    if fixed_state == nil and actor:GetActiveWeapon() == weapon and !actor:is_weapon_raised() then
      block_fire(weapon, cur_time)
    else
      release_fire(weapon, cur_time + (fixed_state == nil and raise_fire_delay() or 0))
    end

    if weapon.OnRaised then
      weapon:OnRaised(actor, cur_time)
    end

    --- Called on the server after a player's weapon has been raised. It can fire again,
    -- unless the player is running while the `sprint_lowers_weapon` config is on or a
    -- ShouldWeaponBeRaised handler keeps the weapon lowered.
    -- For the weapons that cannot be lowered (physgun, gravity gun, tool gun, camera and the
    -- weapons marked as always raised) it is called whichever state was set.
    -- @param actor [Player The player holding the weapon]
    -- @param weapon [Weapon The weapon that has been raised]
    hook.Run('WeaponRaised', actor, weapon)
  else
    if fixed_state == nil then
      block_fire(weapon, cur_time)
    elseif weapon.fl_fire_blocked then
      release_fire(weapon, cur_time)
    end

    if weapon.OnLowered then
      weapon:OnLowered(actor, cur_time)
    end

    --- Called on the server after a player's weapon has been lowered and its fire has been
    -- blocked. The fire of a weapon that is never raised is left alone.
    -- @param actor [Player The player holding the weapon]
    -- @param weapon [Weapon The weapon that has been lowered]
    hook.Run('WeaponLowered', actor, weapon)
  end
end

--- Keeps the player's active weapon from firing for as long as it is lowered, and lets it
-- fire again when it stops being lowered without `Player:set_weapon_raised` having been
-- called: the player has stopped running, a ShouldWeaponBeRaised handler no longer keeps
-- it down or the `weapon_raise_enabled` config has been turned off. A weapon that is never
-- raised is not kept from firing.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function PLUGIN:PlayerThink(actor, cur_time)
  local weapon = actor:GetActiveWeapon()

  if IsValid(weapon) then
    local fixed_state = fixed_raise_state(weapon)

    if fixed_state == nil and !actor:is_weapon_raised() then
      block_fire(weapon, cur_time)
    elseif weapon.fl_fire_blocked then
      release_fire(weapon, cur_time + (fixed_state == nil and raise_fire_delay() or 0))
    end
  end
end

--- Tells the animation code whether to use the raised weapon animations for the player.
-- @param actor [Player]
-- @param model [String the player's model]
-- @return [Boolean whether the player's weapon is raised]
function PLUGIN:ModelWeaponRaised(actor, model)
  return actor:is_weapon_raised()
end

--- Registers the WeaponRaised data table boolean on the player.
-- @param target [Player]
function PLUGIN:PlayerSetupDataTables(target)
  target:DTVar('Bool', BOOL_WEAPON_RAISED, 'WeaponRaised')
end

local player_meta = FindMetaTable('Player')

--- Raises or lowers the player's active weapon and runs the OnWeaponRaised hook.
-- Does nothing clientside. The CanPlayerRaiseWeapon hook can veto the change, and a weapon
-- that is never raised (see the `never_raised` item field and the `NeverRaised` weapon field)
-- is not raised.
-- @param raised [Boolean true to raise the weapon, false to lower it]
function player_meta:set_weapon_raised(raised)
  if SERVER then
    local weapon = self:GetActiveWeapon()

    if raised and IsValid(weapon) and fixed_raise_state(weapon) == false then
      return
    end

    --- Asks whether the raised state of a player's weapon may be changed.
    -- Called on the server by `Player:set_weapon_raised`, for lowering as well as for raising.
    -- It is not asked about raising a weapon that is never raised.
    -- @param actor [Player The player holding the weapon]
    -- @param raised [Boolean True if the weapon is about to be raised and false if it is about
    --   to be lowered]
    -- @return [Boolean Return false to leave the weapon as it is]
    if hook.Run('CanPlayerRaiseWeapon', self, raised) != false then
      self:SetDTBool(BOOL_WEAPON_RAISED, raised)

      --- Called on the server after the raised state of a player's weapon has been set.
      -- The gamemode plays the raise or lower gesture from it, and the plugin runs
      -- `UpdateWeaponRaised`.
      -- @param actor [Player The player holding the weapon]
      -- @param weapon [Weapon The active weapon of the player, which may not be valid]
      -- @param raised [Boolean Whether the weapon is now raised]
      hook.Run('OnWeaponRaised', self, weapon, raised)
    end
  end
end

--- Checks whether the player's active weapon is raised. Without a valid weapon this is
-- false. The physgun, gravity gun, tool gun, camera and the weapons marked as always raised
-- are always raised, and the weapons marked as never raised never are. Otherwise the
-- ShouldWeaponBeRaised hook decides. If it does not, the weapon of a running player is
-- lowered when the `sprint_lowers_weapon` config is on, any other weapon is raised when the
-- `weapon_raise_enabled` config is off, and the networked state is used in the end.
-- @return [Boolean]
function player_meta:is_weapon_raised()
  local weapon = self:GetActiveWeapon()

  if !IsValid(weapon) then
    return false
  end

  local fixed_state = fixed_raise_state(weapon)

  if fixed_state != nil then
    return fixed_state
  end

  --- Lets plugins force a player's weapon to count as raised or as lowered.
  -- Called on both realms every time `Player:is_weapon_raised` is asked about a weapon that
  -- can be both raised and lowered: not for the physgun, gravity gun, tool gun and camera,
  -- nor for the weapons marked as always or never raised.
  -- @param actor [Player The player holding the weapon]
  -- @param weapon [Weapon The active weapon of the player]
  -- @return [Boolean Return true or false to override the state; the configs of the plugin
  --   and the networked state are used when nothing is returned]
  local should_raise = hook.Run('ShouldWeaponBeRaised', self, weapon)

  if should_raise != nil then
    return should_raise
  end

  if Config.get('sprint_lowers_weapon') and self:running() then
    return false
  end

  if !Config.get('weapon_raise_enabled', true) then
    return true
  end

  if self:GetDTBool(BOOL_WEAPON_RAISED) then
    return true
  end

  return false
end

--- Raises the player's active weapon if it is lowered and lowers it if it is raised.
-- Does nothing clientside.
function player_meta:toggle_weapon_raised()
  self:set_weapon_raised(!self:is_weapon_raised())
end
