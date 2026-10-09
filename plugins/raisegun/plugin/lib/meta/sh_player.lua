--- Player extensions of the Raise Weapon plugin: reading and changing the raised state of
-- the player's active weapon. The state is a data table variable of the player, so it is
-- read on both realms, but it is only changed on the server.
-- @module [Player]

local player_meta = FindMetaTable('Player')

--- Raises or lowers the player's active weapon and runs the OnWeaponRaised hook.
-- Does nothing clientside. The CanPlayerRaiseWeapon hook can veto the change, and a weapon
-- that is never raised (see the `never_raised` item field and the `NeverRaised` weapon field)
-- is not raised.
-- @param raised [Boolean true to raise the weapon, false to lower it]
function player_meta:set_weapon_raised(raised)
  if SERVER then
    local weapon = self:GetActiveWeapon()

    if raised and IsValid(weapon) and RaiseGun:get_fixed_state(weapon) == false then
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

  local fixed_state = RaiseGun:get_fixed_state(weapon)

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
