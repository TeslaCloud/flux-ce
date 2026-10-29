--- Client side of the Observer plugin: the indicator a hidden player sees on their HUD.

--- Draws the vanish indicator in the bottom right corner.
function Observer:draw_vanish_indicator()
  local text, font = t'ui.hud.vanish', Theme.get_font('text_normal')
  local w, h = util.text_size(text, font)
  local x, y = ScrW() - w - 16, ScrH() - h - 16

  FontAwesome:draw('fa-eye-slash', x - h - math.scale(12), y, h)
  draw.SimpleText(text, font, x, y, color_white)
end
