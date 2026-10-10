--- The scrolling container of Lumen (`lumen_scroll`), behind the `scroll` element. A
-- `DScrollPanel` whose canvas lays the children out as a flex container of unconstrained
-- height, so that it grows with its content and the scrollbar appears when the content is
-- taller than the panel. `set_scrollbar_visible(false)` hides the bar while keeping the wheel
-- working. Derives from `DScrollPanel`.

local math_max = math.max

local PANEL = {}
PANEL.scrollbar_visible = true

--- Lets the canvas be laid out by the scroll panel alone.
function PANEL:Init()
  self:GetCanvas().PerformLayout = function() end
end

--- Shows or hides the scrollbar.
-- @param visible [Boolean]
function PANEL:set_scrollbar_visible(visible)
  self.scrollbar_visible = visible != false

  local bar = self.VBar

  if !IsValid(bar) then return end

  if self.scrollbar_visible then
    bar.Paint = nil
    bar.btnUp.Paint = nil
    bar.btnDown.Paint = nil
    bar.btnGrip.Paint = nil
  else
    bar.Paint = function() return true end
    bar.btnUp.Paint = function() return true end
    bar.btnDown.Paint = function() return true end
    bar.btnGrip.Paint = function() return true end
  end

  self:InvalidateLayout()
end

--- Lays the children out in the canvas, sizes the canvas to them and sets the scrollbar up.
-- The content is measured first, so that the children are laid out beside the scrollbar when
-- it is going to show.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local style = Lumen.Layout.style_of(self)
  local canvas = self:GetCanvas()
  local bar = self.VBar
  local children = Lumen.Layout.children_of(self)
  local content_w, content_h = Lumen.Layout.flex(style, children, w, nil, false)
  local bar_w = (self.scrollbar_visible and content_h > h) and bar:GetWide() or 0
  local canvas_w = math_max(w - bar_w, 1)

  content_w, content_h = Lumen.Layout.flex(style, children, canvas_w, nil, true)

  canvas:SetSize(canvas_w, math_max(content_h, h))
  bar:SetUp(h, content_h)

  if !self.scrollbar_visible then
    bar:SetWide(0)
  end

  canvas:SetPos(0, bar:GetOffset())
end

--- Measures the size the content needs, for a scroll panel whose size is auto.
-- @param max_w [Number width available, nil if unconstrained]
-- @param max_h [Number height available, nil if unconstrained]
-- @return [Number width, Number height]
function PANEL:lumen_measure(max_w, max_h)
  local style = Lumen.Layout.style_of(self)

  return Lumen.Layout.flex(style, Lumen.Layout.children_of(self), max_w, nil, false)
end

--- Draws the background and the border of the style.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Lumen.paint_box(self, w, h)
end

vgui.Register('lumen_scroll', PANEL, 'DScrollPanel')
