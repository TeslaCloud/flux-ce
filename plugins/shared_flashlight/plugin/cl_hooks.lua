--- Client side of the Shared Flashlight plugin: puts the light of a flashlight out while its
-- entity is dormant and reshapes the lights when their configs change.

--- Configs that shape the light of a flashlight.
const light_configs = {
  shared_flashlight_fov = true,
  shared_flashlight_distance = true,
  shared_flashlight_brightness = true,
  shared_flashlight_shadows = true
}

--- Puts the light of a flashlight out when its entity leaves the view of the client, since a
-- dormant entity does not think; the light comes back on its first think once the entity
-- returns.
-- @param entity [Entity]
-- @param should_transmit [Boolean whether the entity has come into view]
function SharedFlashlight:NotifyShouldTransmit(entity, should_transmit)
  if !should_transmit and entity:GetClass() == 'fl_flashlight' then
    entity:switch_off()
  end
end

--- Reshapes every lit flashlight when one of the configs of the light arrives from the
-- server.
-- @param key [String key of the config]
-- @param _old_value [Any]
-- @param _new_value [Any]
function SharedFlashlight:ConfigReceived(key, _old_value, _new_value)
  if !light_configs[key] then return end

  for _, light in pairs(self.lights) do
    if IsValid(light) then
      light:apply_config()
    end
  end
end
