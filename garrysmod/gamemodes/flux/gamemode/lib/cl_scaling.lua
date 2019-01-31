--[[
  Automatic Screen Scaling code
--]]

-- do not refresh
if set_screen_scale or !Settings.experimental then return end

local scale = 1

function set_screen_scale(new_scale)
  scale = new_scale
  return scale
end

function get_screen_scale()
  return scale
end

-- Overrides.
local old = {
  scr_w = ScrW,
  scr_h = ScrH,
  draw_rect = surface.DrawRect,
  set_text_pos = surface.SetTextPos,
  draw_textured_rect = surface.DrawTexturedRect,
  draw_textured_rect_rotated = surface.DrawTexturedRectRotated,
  draw_textured_rect_uv = surface.DrawTexturedRectUV,
  draw_outlined_rect = surface.DrawOutlinedRect,
  draw_line = surface.DrawLine,
  draw_poly = surface.DrawPoly,
  draw_circle = surface.DrawCircle,
  create_font = surface.CreateFont,
  scissor_rect = render.SetScissorRect
}

function ScrW()
  return old.scr_w() / scale
end

function ScrH()
  return old.scr_h() / scale
end

function surface.DrawRect(x, y, w, h)
  return old.draw_rect(x * scale, y * scale, w * scale, h * scale)
end

function surface.DrawTexturedRect(x, y, w, h)
  return old.draw_textured_rect(x * scale, y * scale, w * scale, h * scale)
end

function surface.DrawTexturedRectRotated(x, y, w, h, rotation)
  return old.draw_textured_rect_rotated(x * scale, y * scale, w * scale, h * scale, rotation)
end

function surface.DrawTexturedRectUV(x, y, w, h, su, sv, eu, ev)
  return old.draw_textured_rect_uv(x * scale, y * scale, w * scale, h * scale, su, sv, eu, ev)
end

function surface.DrawOutlinedRect(x, y, w, h)
  return old.draw_outlined_rect(x * scale, y * scale, w * scale, h * scale)
end

function surface.DrawLine(sx, sy, ex, ey)
  return old.draw_line(sx * scale, sy * scale, ex * scale, ey * scale)
end

function surface.DrawPoly(vertices, no_scaling)
  if vertices.scaled then do_scale = true end

  if no_scaling then
    return old.draw_poly(vertices)
  else
    for k, v in ipairs(vertices) do
      vertices[k].x = v.x * scale
      vertices[k].y = v.y * scale
    end

    vertices.scaled = true

    return old.draw_poly(vertices)
  end
end

function surface.SetTextPos(x, y)
  return old.set_text_pos(x * scale, y * scale)
end

function surface.CreateFont(name, data)
  data.size = (data.size or 0) * scale
  return old.create_font(name, data)
end

function surface.DrawCircle(x, y, radius, r, g, b, a)
  return old.draw_circle(x * scale, y * scale, radius * scale, r, g, b, a)
end

function render.SetScissorRect(sx, sy, ex, ey, enable)
  return old.scissor_rect(sx * scale, sy * scale, ex * scale, ey * scale, enable)
end

-- Panel overrides.
local panel_meta = FindMetaTable('Panel')
panel_meta.old_set_pos = panel_meta.SetPos
panel_meta.old_set_size = panel_meta.SetSize
panel_meta.old_get_size = panel_meta.GetSize
panel_meta.old_get_wide = panel_meta.GetWide
panel_meta.old_get_tall = panel_meta.GetTall
panel_meta.old_move_to = panel_meta.MoveTo
panel_meta.old_size_to = panel_meta.SizeTo
local old_vgui_create = vgui.Create

function panel_meta:SetPos(x, y)
  return self:old_set_pos(x * scale, y * scale)
end

function panel_meta:SetSize(w, h)
  return self:old_set_size(w * scale, h * scale)
end

function panel_meta:GetSize()
  local x, y = self:old_get_size()
  return x / scale, y / scale
end

function panel_meta:GetWide()
  return self:old_get_wide() / scale
end

function panel_meta:GetTall()
  return self:old_get_tall() / scale
end

function panel_meta:MoveTo(x, y, time, delay, ease, callback)
  return self:old_move_to(x * scale, y * scale, time, delay, ease, callback)
end

function panel_meta:SizeTo(x, y, time, delay, ease, callback)
  return self:old_size_to(x * scale, y * scale, time, delay, ease, callback)
end

function vgui.Create(name, parent, pname)
  local pane = old_vgui_create(name, parent, pname)
  pane.old_paint = pane.Paint
  pane.Paint = function(s, w, h)
    if pane.old_paint then
      return pane.old_paint(s, w / scale, h / scale)
    end
  end
  return pane
end
