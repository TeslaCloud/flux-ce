--- Player extensions of the Shared Flashlight plugin: reading and changing the player's
-- flashlight, whichever flashlight is in use. The state is a networked variable of the
-- player, so it is read on both realms, but it is only changed on the server.
-- @module [Player]

local player_meta = FindMetaTable('Player')

--- Checks whether the player's flashlight is on: the shared flashlight or, while the
-- `shared_flashlight_enabled` config is off, the engine one.
-- @return [Boolean]
function player_meta:is_flashlight_on()
  return self:get_nv('fl_flashlight_on', false) or self:FlashlightIsOn()
end

--- Returns the entity of the player's shared flashlight.
-- @return [Entity the fl_flashlight entity, or nil while the shared flashlight is off or its
--   entity has not reached the client yet]
function player_meta:get_flashlight()
  local light = SERVER and self.fl_flashlight or SharedFlashlight.lights[self]

  if IsValid(light) then
    return light
  end
end

--- Turns the player's flashlight on or off and runs the PlayerFlashlightChanged hook.
-- Does nothing clientside. While the `shared_flashlight_enabled` config is on, turning the
-- flashlight on creates an `fl_flashlight` entity parented to the player, which is removed
-- along with the player, and turning it off removes that entity; the engine flashlight is
-- put out either way, in case the config was turned on while it was lit. While the config
-- is off the engine flashlight is toggled instead.
-- @param on [Boolean true to turn the flashlight on, false to turn it off]
function player_meta:set_flashlight(on)
  if !SERVER then return end

  if !SharedFlashlight:is_enabled() then
    self:Flashlight(on)
    self:set_nv('fl_flashlight_on', false)

    return
  end

  if self:FlashlightIsOn() then
    self:Flashlight(false)
  end

  local light = self:get_flashlight()

  if on and !light then
    light = ents.Create('fl_flashlight')

    if !IsValid(light) then return end

    light:SetPos(self:EyePos())
    light:SetOwner(self)
    light:SetParent(self)
    light:Spawn()

    self:DeleteOnRemove(light)
    self.fl_flashlight = light
  elseif !on and light then
    light:Remove()
    self.fl_flashlight = nil
  end

  self:set_nv('fl_flashlight_on', on and true or false)

  --- Called on the server after a player's flashlight has been turned on or off through
  -- `Player:set_flashlight`, whether the shared or the engine flashlight is in use.
  -- @param actor [Player The player whose flashlight has changed]
  -- @param on [Boolean Whether the flashlight is now on]
  hook.Run('PlayerFlashlightChanged', self, on)
end
