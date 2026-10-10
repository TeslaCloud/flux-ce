--- A horizontal row of panels (`fl_horizontalbar`) that can be scrolled when its contents do
-- not fit.
-- It extends `DHorizontalScroller`: add panels with `AddPanel` and they are lined up from the
-- left and stretched to the height of the bar, or centered after `set_centered(true)`. The
-- background is left to the active theme's `PaintHorizontalbar` hook. Used for the character
-- list, the stages of the character creation and the faction chooser.

local PANEL = {}
PANEL.centered = false

--- Hides the scroll buttons of the underlying DHorizontalScroller until there is something
-- to scroll to.
function PANEL:Init()
  self.btnLeft:SetVisible(false)
  self.btnRight:SetVisible(false)
end

--- Delegates drawing of the bar to the active theme's PaintHorizontalbar hook.
-- @param width [Number panel width]
-- @param height [Number panel height]
function PANEL:Paint(width, height)
  Theme.hook('PaintHorizontalbar', self, width, height)
end

--- Adds a panel to the bar and immediately lays the bar out again.
-- @param pnl [Panel]
function PANEL:AddPanel(pnl)
  table.insert(self.Panels, pnl)

  pnl:SetParent(self.pnlCanvas)
  self:InvalidateLayout(true)
end

--- Lines the child panels up from left to right, or centers them when set_centered is on
-- and they fit into the bar, stretches them to the height of the bar, clamps the scroll
-- offset and shows the scroll buttons for the sides that have panels out of view.
function PANEL:PerformLayout()
  local w, h = self:GetSize()
  local x = 0
  local panels = self.Panels
  local overlap = self.m_iOverlap
  local canvas = self.pnlCanvas

  canvas:SetTall(h)

  if self.centered then
    local wide = 0
    local panel_count = #panels

    for k, v in pairs(panels) do
      wide = wide + v:GetWide() + (k != panel_count and overlap or 0)
    end

    -- Panels that do not fit start at the left edge instead, as whatever ends up left of
    -- the canvas can never be scrolled into view.
    x = math.max(w * 0.5 - wide * 0.5, 0)
  end

  for k, v in pairs(panels) do
    if !IsValid(v) then continue end

    v:SetPos(x, 0)
    v:SetTall(h)

    x = x + v:GetWide() + overlap
  end

  canvas:SetWide(math.max(x - overlap, 0))

  local canvas_w = canvas:GetWide()

  if w < canvas_w then
    self.OffsetX = math.Clamp(self.OffsetX, 0, canvas_w - w)
  else
    self.OffsetX = 0
  end

  canvas.x = self.OffsetX * -1

  local button_size = math.scale(16)

  self.btnLeft:SetSize(button_size, button_size)
  self.btnLeft:AlignLeft(4)
  self.btnLeft:CenterVertical()

  self.btnRight:SetSize(button_size, button_size)
  self.btnRight:AlignRight(4)
  self.btnRight:CenterVertical()

  self.btnLeft:SetVisible(canvas.x < 0)
  self.btnRight:SetVisible(canvas.x + canvas_w > w)
end

--- Sets whether the child panels are centered horizontally instead of aligned to the left.
-- @param centered [Boolean]
function PANEL:set_centered(centered)
  self.centered = centered
end

vgui.Register('fl_horizontalbar', PANEL, 'DHorizontalScroller')
