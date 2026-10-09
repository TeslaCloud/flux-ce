--- Server side of the Shared Flashlight plugin: toggles the light when the flashlight key is
-- pressed, puts it out on death and on the way back to the engine flashlight.

--- Toggles the player's shared flashlight and keeps the engine flashlight from toggling.
-- The engine always asks to turn its flashlight on, since it never gets to turn on, so the
-- player's current state decides which way the toggle goes. Does nothing while the
-- `shared_flashlight_enabled` config is off, which leaves the decision to the base gamemode.
-- @param actor [Player]
-- @param on [Boolean whether the engine flashlight is being turned on]
-- @return [Boolean false while the plugin is enabled, nil otherwise]
function SharedFlashlight:PlayerSwitchedFlashlight(actor, on)
  if !self:is_enabled() then return end

  actor:set_flashlight(!actor:is_flashlight_on())

  return false
end

--- Puts the flashlight of a player out when they die.
-- @param victim [Player]
-- @param inflictor [Entity]
-- @param attacker [Entity]
function SharedFlashlight:PlayerDeath(victim, inflictor, attacker)
  victim:set_flashlight(false)
end

--- Puts every shared flashlight out when the `shared_flashlight_enabled` config is turned
-- off, so that nobody keeps a light the engine flashlight has taken over from.
-- @param key [String key of the config that has changed]
-- @param old_value [Any]
-- @param new_value [Any]
function SharedFlashlight:OnConfigSet(key, old_value, new_value)
  if key == 'shared_flashlight_enabled' and !new_value then
    for k, v in player.Iterator() do
      if IsValid(v:get_flashlight()) then
        v:set_flashlight(false)
      end
    end
  end
end
