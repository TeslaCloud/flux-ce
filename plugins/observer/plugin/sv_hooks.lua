--- Server side of the Observer plugin: turns noclip into observer mode and takes a player who
-- dies in observer mode out of it.

--- Puts the player into observer mode in place of the default noclip, if they have the
-- 'noclip' permission. See Observer#start_observing.
-- @param actor [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerCanEnterNoclip(actor)
  if !actor:can('noclip') then
    actor:notify('error.no_permission')

    return false
  end

  self:start_observing(actor)

  return false
end

--- Takes the player out of observer mode in place of the default noclip. See
-- Observer#stop_observing.
-- @param actor [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerCanExitNoclip(actor)
  self:stop_observing(actor)

  return false
end

--- Keeps players where they are when leaving observer mode if the 'observer_reset' config
-- is off.
-- @param _actor [Player]
-- @return [Boolean false if the player should not be moved back, nil otherwise]
function Observer:ShouldObserverReset(_actor)
  if !Config.get('observer_reset') then
    return false
  end
end

--- Takes a player who dies in observer mode out of it, so that they do not respawn invisible
-- and invulnerable. They are not moved back to where they entered it.
-- @param victim [Player]
-- @param _inflictor [Entity]
-- @param _attacker [Entity]
function Observer:PlayerDeath(victim, _inflictor, _attacker)
  if !victim:get_nv('observer') then return end

  if victim.observer_data then
    victim.observer_data.should_reset = false
  end

  self:stop_observing(victim)
end
