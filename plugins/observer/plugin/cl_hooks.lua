--- Client side of the Observer plugin: blocks the default noclip, as observer mode is handled
-- by the server, and draws the vanish indicator and the admin ESP.

local IsValid = IsValid

--- Blocks the default noclip clientside, since observer mode is handled by the server.
-- @param _actor [Player]
-- @return [Boolean always false]
function Observer:PlayerCanEnterNoclip(_actor)
  return false
end

--- Blocks the default noclip clientside, since observer mode is handled by the server.
-- @param _actor [Player]
-- @return [Boolean always false]
function Observer:PlayerCanExitNoclip(_actor)
  return false
end

--- Draws the vanish indicator while the local player is hidden from other players, and the
-- admin ESP while they noclip outside of a vehicle and have the 'admin_esp' permission.
function Observer:HUDPaint()
  local client = PLAYER

  if !IsValid(client) or !client:Alive() then return end

  if client:get_nv('transmission_prevented') and client:has_initialized() then
    self:draw_vanish_indicator()
  end

  if client:GetMoveType() == MOVETYPE_NOCLIP and !client:InVehicle() and can('admin_esp') then
    self:draw_esp(client)
  end
end

--- Refreshes the ESP colors from the theme that has just been loaded.
-- @param current_theme [ThemeBase the loaded theme]
function Observer:OnThemeLoaded(current_theme)
  self:set_esp_colors(current_theme)
end
