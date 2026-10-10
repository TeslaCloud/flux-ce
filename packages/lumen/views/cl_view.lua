--- The flex container of Lumen (`lumen_view`), the panel behind the `view` and `spacer`
-- elements. It lays its children out with `Lumen.Layout` from its resolved style, draws the
-- background and the border the style asks for, and fires the `on_press` and `on_right_press`
-- props. Derives from `EditablePanel`.

local PANEL = {}

--- Lays the children out as a flex container.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local style = Lumen.Layout.style_of(self)

  Lumen.Layout.flex(style, Lumen.Layout.children_of(self), w, h, true)
end

--- Measures the size the children need, for a view whose size is auto.
-- @param max_w [Number width available, nil if unconstrained]
-- @param max_h [Number height available, nil if unconstrained]
-- @return [Number width, Number height]
function PANEL:lumen_measure(max_w, max_h)
  local style = Lumen.Layout.style_of(self)

  return Lumen.Layout.flex(style, Lumen.Layout.children_of(self), max_w, max_h, false)
end

--- Draws the background and the border of the style.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Lumen.paint_box(self, w, h)
end

--- Fires the press handlers of the element.
-- @param code [Number mouse button]
function PANEL:OnMousePressed(code)
  Lumen.press_handler(self, code)
end

vgui.Register('lumen_view', PANEL, 'EditablePanel')

local draw_rounded_box     = draw.RoundedBox
local surface_set_color    = surface.SetDrawColor
local surface_draw_rect    = surface.DrawRect
local surface_draw_outline = surface.DrawOutlinedRect

--- Draws the background and the border that a resolved style asks for.
-- @param panel [Panel a panel with a `lumen_style`]
-- @param w [Number panel width]
-- @param h [Number panel height]
-- @param background=nil [Color background to draw instead of the one of the style]
function Lumen.paint_box(panel, w, h, background)
  local style = panel.lumen_style

  if !style then return end

  background = background or style.background

  local border = style.border
  local radius = style.radius or 0

  if border then
    local border_width = style.border_width or 1

    if radius > 0 then
      draw_rounded_box(radius, 0, 0, w, h, border)

      if background then
        draw_rounded_box(
          math.max(radius - border_width, 0),
          border_width,
          border_width,
          w - border_width * 2,
          h - border_width * 2,
          background
        )
      end
    else
      if background then
        surface_set_color(background)
        surface_draw_rect(0, 0, w, h)
      end

      surface_set_color(border)

      for i = 0, border_width - 1 do
        surface_draw_outline(i, i, w - i * 2, h - i * 2)
      end
    end
  elseif background then
    if radius > 0 then
      draw_rounded_box(radius, 0, 0, w, h, background)
    else
      surface_set_color(background)
      surface_draw_rect(0, 0, w, h)
    end
  end
end
