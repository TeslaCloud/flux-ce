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
-- `RaiseGun:get_fixed_state` tells what the fields make of a weapon.
--
-- The plugin has three configs, whose defaults leave it working the way it does without
-- them: `weapon_raise_enabled` turns the lowering of weapons off altogether,
-- `sprint_lowers_weapon` lowers the weapon of a running player, and `weapon_raise_fire_delay`
-- is the time a weapon cannot fire for after it has been raised.
-- @module [RaiseGun]

PLUGIN:set_global('RaiseGun')

local config_get = Config.get

BOOL_WEAPON_RAISED = 1

RaiseGun.weapon_items = RaiseGun.weapon_items or {}

local blocked_weapons = {
  ['weapon_physgun'] = true,
  ['gmod_tool'] = true,
  ['gmod_camera'] = true,
  ['weapon_physcannon'] = true
}

--- How far ahead, in seconds, the next fire of a lowered weapon is put to keep it from
-- firing.
local fire_block_time = 86400

--- The next fire of a lowered weapon that is closer than this many seconds has been moved
-- by the weapon itself since it was blocked, and has to be blocked again.
local fire_block_floor = 3600

--- Finds the item that gives a weapon: the item template whose `weapon_class` is the class
-- of the weapon. Base items are skipped, and of several items that give the same weapon the
-- one whose ID comes first alphabetically is taken, so that the server and the clients agree.
-- The answer is remembered for every class until the schema is loaded again.
-- @param class [String weapon class]
-- @return [Item item template, or nil if no item gives the weapon or the items plugin is not
--   loaded]
function RaiseGun:find_weapon_item(class)
  local cached = self.weapon_items[class]

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

  self.weapon_items[class] = found

  return found or nil
end

--- Reads one of the raise settings of a weapon: from the item that gives the weapon if the
-- item sets it, from the weapon itself otherwise.
-- @param weapon [Weapon]
-- @param class [String class of the weapon]
-- @param item_key [String name of the field of the item, e.g. 'never_raised']
-- @param weapon_key [String name of the field of the weapon, e.g. 'NeverRaised']
-- @return [Any value of the field, nil if neither the item nor the weapon sets it]
function RaiseGun:weapon_option(weapon, class, item_key, weapon_key)
  local item_obj = self:find_weapon_item(class)

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
function RaiseGun:get_fixed_state(weapon)
  local class = weapon:GetClass()

  if blocked_weapons[class] or self:weapon_option(weapon, class, 'always_raised', 'AlwaysRaised') then
    return true
  end

  if self:weapon_option(weapon, class, 'never_raised', 'NeverRaised') then
    return false
  end
end

--- Returns the time a weapon that has just been raised cannot fire for.
-- @return [Number seconds from the `weapon_raise_fire_delay` config; 0 while the
--   `weapon_raise_enabled` config is off]
function RaiseGun:get_fire_delay()
  if !config_get('weapon_raise_enabled', true) then
    return 0
  end

  return config_get('weapon_raise_fire_delay', 0)
end

--- Keeps a weapon from firing, for a day unless `RaiseGun:release_fire` lets it fire again
-- before that, and marks it as blocked by the plugin.
-- @param weapon [Weapon]
-- @param cur_time [Number CurTime() of the call]
function RaiseGun:block_fire(weapon, cur_time)
  weapon:SetNextPrimaryFire(cur_time + fire_block_time)
  weapon:SetNextSecondaryFire(cur_time + fire_block_time)

  weapon.fl_fire_blocked = true
end

--- Tells whether a weapon that `RaiseGun:block_fire` has blocked has moved its own next fire
-- closer since, on a reload for example, so that it could fire although it is lowered.
-- @param weapon [Weapon]
-- @param cur_time [Number CurTime() of the call]
-- @return [Boolean true if either fire is less than an hour away]
function RaiseGun:is_fire_unblocked(weapon, cur_time)
  local floor = cur_time + fire_block_floor

  return weapon:GetNextPrimaryFire() < floor or weapon:GetNextSecondaryFire() < floor
end

--- Lets a weapon fire again from the given time on and clears the mark left by
-- `RaiseGun:block_fire`.
-- @param weapon [Weapon]
-- @param next_fire [Number CurTime() based time of the first shot that is allowed]
function RaiseGun:release_fire(weapon, next_fire)
  weapon:SetNextPrimaryFire(next_fire)
  weapon:SetNextSecondaryFire(next_fire)

  weapon.fl_fire_blocked = nil
end

--- Forgets which items give which weapons, so that they are looked up again among the items
-- of the schema and the plugins that have just been loaded.
function RaiseGun:OnSchemaLoaded()
  self.weapon_items = {}
end

--- Starts a one second timer that toggles the player's weapon raise when reload is pressed.
-- Does nothing while the `weapon_raise_enabled` config is off.
-- @param actor [Player]
-- @param key [Number IN_ enum of the pressed key]
function RaiseGun:KeyPress(actor, key)
  if key == IN_RELOAD and config_get('weapon_raise_enabled', true) then
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
function RaiseGun:KeyRelease(actor, key)
  if key == IN_RELOAD then
    timer.Remove('fl_weapon_raise_'..actor:SteamID())
  end
end

--- Tells the animation code whether to use the raised weapon animations for the player.
-- @param actor [Player]
-- @param model [String the player's model]
-- @return [Boolean whether the player's weapon is raised]
function RaiseGun:ModelWeaponRaised(actor, model)
  return actor:is_weapon_raised()
end

--- Registers the WeaponRaised data table boolean on the player.
-- @param target [Player]
function RaiseGun:PlayerSetupDataTables(target)
  target:DTVar('Bool', BOOL_WEAPON_RAISED, 'WeaponRaised')
end

require_relative 'cl_hooks'
require_relative 'sv_hooks'
