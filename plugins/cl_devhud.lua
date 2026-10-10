--- Flux Dev HUD prints the versions of Flux and of its core in the bottom left corner of the
-- screen while the game runs in development mode.
-- Plugins can replace the line through the `HUDPaintDeveloper` hook.
-- @environment [development]

PLUGIN:set_name('Flux Dev HUD')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds a developer HUD.')

local version_color = Color(200, 100, 100, 200)

--- Draws the Flux and core version line in the bottom left corner while in development mode.
-- Skipped when the HUDPaintDeveloper hook returns anything.
function PLUGIN:HUDPaint()
  if Flux.development then
    --- Called on the client on every HUD paint in development mode, before the version line of
    -- the developer HUD is drawn.
    -- Handlers can draw their own developer information here.
    -- @return [Any Return anything but nil to hide the default version line]
    if hook.Run('HUDPaintDeveloper') == nil then
      local flow_version = (Flow and Flow.__package__ and Flow.__package__.version) or 'UNKNOWN'
      local font = Theme.get_font('text_smallest', 'default')

      draw.SimpleText(
        'Flux version '..(GAMEMODE.version or 'UNKNOWN')..'. Core version '..flow_version..'.',
        font,
        math.scale(8),
        ScrH() - math.scale(4) - util.font_size(font),
        version_color
      )
    end
  end
end
