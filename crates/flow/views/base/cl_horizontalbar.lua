local PANEL = {}
PANEL.centered = false

--- Hides the scroll buttons of the underlying DHorizontalScroller.
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

--- Lines the child panels up from left to right, or centers them when set_centered is on,
-- stretches them to the height of the bar and clamps the scroll offset.
function PANEL:PerformLayout()
  local w, h = self:GetSize()
  local x = 0

  self.pnlCanvas:SetTall(h)

  if self.centered then
    local wide = 0

    for k, v in pairs(self.Panels) do
      wide = wide + v:GetWide() + (k != #self.Panels and self.m_iOverlap or 0)
    end

    x = w * 0.5 - wide * 0.5
  end

  for k, v in pairs(self.Panels) do
    if !IsValid(v) then continue end

    v:SetPos(x, 0)
    v:SetTall(h)

    x = x + v:GetWide() + self.m_iOverlap
  end

  self.pnlCanvas:SetWide(x + self.m_iOverlap)

  if (w < self.pnlCanvas:GetWide()) then
    self.OffsetX = math.Clamp(self.OffsetX, 0, self.pnlCanvas:GetWide() - self:GetWide())
  else
    self.OffsetX = 0
  end

  self.pnlCanvas.x = self.OffsetX * -1
end

--- Sets whether the child panels are centered horizontally instead of aligned to the left.
-- @param centered [Boolean]
function PANEL:set_centered(centered)
  self.centered = centered
end

vgui.Register('fl_horizontalbar', PANEL, 'DHorizontalScroller')
