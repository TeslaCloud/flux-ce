--- Raise Weapon keeps weapons lowered until the player raises them by holding the reload key
-- for a second.
-- Holding the key again lowers the weapon, and so does switching weapons. A lowered weapon
-- cannot fire and is held in a lowered pose; the physgun, gravity gun, tool gun and camera
-- always count as raised. The state is read and changed with `Player:is_weapon_raised`,
-- `Player:set_weapon_raised` and `Player:toggle_weapon_raised`, and plugins take part through
-- the `CanPlayerRaiseWeapon`, `ShouldWeaponBeRaised`, `OnWeaponRaised`, `WeaponRaised`,
-- `WeaponLowered` and `CanPlayerAttack` hooks.
-- @module [PLUGIN]

PLUGIN:set_name('Raise Weapon')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Allows weapons to be lowered and raised by holding the R key.')

BOOL_WEAPON_RAISED = 1

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

if CLIENT then
  --- Rotates the view model into the lowered pose while the local player's weapon is not
  -- raised, then lets the weapon's GetViewModelPosition and CalcViewModelView adjust it.
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
    local rotation = rotation_translate[weapon:GetClass()] or rotation_translate['default']

    eye_angles:RotateAroundAxis(eye_angles:Up(), rotation.p * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Forward(), rotation.y * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Right(), rotation.r * fraction)

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

    return old_eye_pos, eye_angles
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

  --- Prevents the local player from attacking while their weapon is lowered.
  -- @return [Boolean false if the weapon is lowered, nil otherwise]
  function PLUGIN:CanPlayerAttack()
    if !PLAYER:is_weapon_raised() then
      return false
    end
  end
end

--- Starts a one second timer that toggles the player's weapon raise when reload is pressed.
-- @param actor [Player]
-- @param key [Number IN_ enum of the pressed key]
function PLUGIN:KeyPress(actor, key)
  if key == IN_RELOAD then
    timer.Create('fl_weapon_raise_'..actor:SteamID(), 1, 1, function()
      actor:toggle_weapon_raised()
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
-- @param actor [Player]
-- @param weapon [Weapon]
-- @param raised [Boolean whether the weapon is now raised]
-- @param cur_time [Number CurTime() of the change]
function PLUGIN:UpdateWeaponRaised(actor, weapon, raised, cur_time)
  if raised or blocked_weapons[weapon:GetClass()] then
    weapon:SetNextPrimaryFire(cur_time)
    weapon:SetNextSecondaryFire(cur_time)

    if weapon.OnRaised then
      weapon:OnRaised(actor, cur_time)
    end

    --- Called on the server after a player's weapon has been raised and can fire again.
    -- For the weapons that cannot be lowered (physgun, gravity gun, tool gun and camera) it is
    -- called whichever state was set.
    -- @param actor [Player The player holding the weapon]
    -- @param weapon [Weapon The weapon that has been raised]
    hook.Run('WeaponRaised', actor, weapon)
  else
    weapon:SetNextPrimaryFire(cur_time + 60)
    weapon:SetNextSecondaryFire(cur_time + 60)

    if weapon.OnLowered then
      weapon:OnLowered(actor, cur_time)
    end

    --- Called on the server after a player's weapon has been lowered and its fire has been
    -- blocked.
    -- @param actor [Player The player holding the weapon]
    -- @param weapon [Weapon The weapon that has been lowered]
    hook.Run('WeaponLowered', actor, weapon)
  end
end

--- Keeps the player's active weapon from firing for as long as it is lowered.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function PLUGIN:PlayerThink(actor, cur_time)
  local weapon = actor:GetActiveWeapon()

  if IsValid(weapon) then
    if !actor:is_weapon_raised() then
      weapon:SetNextPrimaryFire(cur_time + 60)
      weapon:SetNextSecondaryFire(cur_time + 60)
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
-- Does nothing clientside. The CanPlayerRaiseWeapon hook can veto the change.
-- @param raised [Boolean true to raise the weapon, false to lower it]
function player_meta:set_weapon_raised(raised)
  if SERVER then
    --- Asks whether the raised state of a player's weapon may be changed.
    -- Called on the server by `Player:set_weapon_raised`, for lowering as well as for raising.
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
      hook.Run('OnWeaponRaised', self, self:GetActiveWeapon(), raised)
    end
  end
end

--- Checks whether the player's active weapon is raised. Without a valid weapon this is
-- false; physgun, gravity gun, tool gun and camera are always raised. Otherwise the
-- ShouldWeaponBeRaised hook decides, falling back to the networked state.
-- @return [Boolean]
function player_meta:is_weapon_raised()
  local weapon = self:GetActiveWeapon()

  if !IsValid(weapon) then
    return false
  end

  if blocked_weapons[weapon:GetClass()] then
    return true
  end

  --- Lets plugins force a player's weapon to count as raised or as lowered.
  -- Called on both realms every time `Player:is_weapon_raised` is asked about a weapon that
  -- can be lowered.
  -- @param actor [Player The player holding the weapon]
  -- @param weapon [Weapon The active weapon of the player]
  -- @return [Boolean Return true or false to override the state; the networked state is used
  --   when nothing is returned]
  local should_raise = hook.Run('ShouldWeaponBeRaised', self, weapon)

  if should_raise != nil then
    return should_raise
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
