--- Server side of the Raise Weapon plugin: lowers the weapon a player switches to, blocks
-- the fire of a lowered weapon and lets a raised one fire again.

--- Lowers the player's weapon whenever they switch weapons.
-- @param actor [Player]
-- @param old_weapon [Weapon]
-- @param new_weapon [Weapon]
function RaiseGun:PlayerSwitchWeapon(actor, old_weapon, new_weapon)
  actor:set_weapon_raised(false)
end

--- Runs the UpdateWeaponRaised hook with the current time if the weapon is valid.
-- @param actor [Player]
-- @param weapon [Weapon the player's active weapon]
-- @param raised [Boolean whether the weapon is now raised]
function RaiseGun:OnWeaponRaised(actor, weapon, raised)
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
-- fire until it is raised (lowered). Then calls the weapon's OnRaised or OnLowered method
-- and runs the WeaponRaised or WeaponLowered hook.
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
function RaiseGun:UpdateWeaponRaised(actor, weapon, raised, cur_time)
  local fixed_state = self:get_fixed_state(weapon)

  if raised or fixed_state == true then
    if fixed_state == nil and actor:GetActiveWeapon() == weapon and !actor:is_weapon_raised() then
      self:block_fire(weapon, cur_time)
    else
      self:release_fire(weapon, cur_time + (fixed_state == nil and self:get_fire_delay() or 0))
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
      self:block_fire(weapon, cur_time)
    elseif weapon.fl_fire_blocked then
      self:release_fire(weapon, cur_time)
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
-- it down or the `weapon_raise_enabled` config has been turned off. The fire is touched
-- when the state of the weapon flips, which the `fl_fire_blocked` mark on the weapon keeps
-- track of, when the player has switched to the weapon, since deploying it may have let it
-- fire again, and when a lowered weapon has moved its own next fire closer, which a weapon
-- does on a reload for example; the last is a comparison on every tick. A weapon that is
-- never raised is not kept from firing.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function RaiseGun:PlayerThink(actor, cur_time)
  local weapon = actor:GetActiveWeapon()

  if !IsValid(weapon) then return end

  local switched = actor.fl_raise_weapon != weapon
  local fixed_state = self:get_fixed_state(weapon)

  actor.fl_raise_weapon = weapon

  if fixed_state == nil and !actor:is_weapon_raised() then
    if switched or !weapon.fl_fire_blocked or self:is_fire_unblocked(weapon, cur_time) then
      self:block_fire(weapon, cur_time)
    end
  elseif weapon.fl_fire_blocked then
    self:release_fire(weapon, cur_time + (fixed_state == nil and self:get_fire_delay() or 0))
  end
end
