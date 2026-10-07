PLUGIN:set_name('Flux Dev HUD')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds a developer HUD.')

--- Draws the Flux and core version line in the bottom left corner while in development mode.
-- Skipped when the HUDPaintDeveloper hook returns anything.
function PLUGIN:HUDPaint()
  if Flux.development then
    if hook.Run('HUDPaintDeveloper') == nil then
      local flow_version = (Flow and Flow.__package__ and Flow.__package__.version) or 'UNKNOWN'
      draw.SimpleText(
        'Flux version '..(GAMEMODE.version or 'UNKNOWN')..'. Core version '..flow_version..'.',
        'default',
        8,
        ScrH() - 18,
        Color(200, 100, 100, 200)
      )
    end
  end
end
