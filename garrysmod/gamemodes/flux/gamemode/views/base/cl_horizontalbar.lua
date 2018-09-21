local PANEL = {}
PANEL.centered = false

function PANEL:Init()
  self.btnLeft:SetVisible(false)
  self.btnRight:SetVisible(false)
end

function PANEL:SetCentered(bCentered)
  self.centered = bCentered
end

function PANEL:Paint(width, height)
  theme.Hook('PaintHorizontalbar', self, width, height)
end

function PANEL:AddPanel(pnl)
  table.insert(self.Panels, pnl)

  pnl:SetParent(self.pnlCanvas)
  self:InvalidateLayout(true)
end

function PANEL:PerformLayout()
  local w, h = self:GetSize()
  local x = 0

  self.pnlCanvas:SetTall(h)

  if self.centered then
    local wide = 0

    for k, v in pairs(self.Panels) do
      wide = wide + v:GetWide() + self.m_iOverlap
    end

   x = w / 2 - wide / 2
  end

  for k, v in pairs(self.Panels) do
    if (!IsValid(v)) then continue end

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

vgui.Register('fl_horizontalbar', PANEL, 'DHorizontalScroller')
