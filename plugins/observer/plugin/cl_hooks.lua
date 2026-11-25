--- Client side of the Observer plugin: blocks the default noclip, as observer mode is handled
-- by the server, draws the vanish indicator and the admin ESP, and keeps hidden players off
-- the scoreboard of players who cannot see them.

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

--- Checks once a second whether the local player has the 'admin_esp' permission, which
-- `Observer:HUDPaint` reads every frame.
function Observer:OneSecond()
  self.esp_allowed = IsValid(PLAYER) and can('admin_esp')
end

--- Draws the vanish indicator while the local player is hidden from other players, and the
-- admin ESP while they noclip outside of a vehicle and have the 'admin_esp' permission, as
-- checked by `Observer:OneSecond`.
function Observer:HUDPaint()
  local client = PLAYER

  if !IsValid(client) or !client:Alive() then return end

  if client:get_nv('transmission_prevented') and client:has_initialized() then
    self:draw_vanish_indicator()
  end

  if client:GetMoveType() == MOVETYPE_NOCLIP and !client:InVehicle() and self.esp_allowed then
    self:draw_esp(client)
  end
end

--- Refreshes the ESP colors from the theme that has just been loaded.
-- @param current_theme [ThemeBase the loaded theme]
function Observer:ThemeLoaded(current_theme)
  self:set_esp_colors(current_theme)
end

--- Keeps other hidden players off the scoreboard unless the local player has the 'moderate'
-- permission, which lets them see hidden players.
-- @param target [Player]
-- @return [Boolean false for a hidden player the local player cannot see, nil otherwise]
function Observer:ShouldShowPlayerOnScoreboard(target)
  if target != PLAYER and target:get_nv('hidden') and !can('moderate') then
    return false
  end
end
