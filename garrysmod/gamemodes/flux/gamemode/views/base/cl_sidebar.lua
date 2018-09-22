local PANEL = {}
PANEL.lastPos = 0
PANEL.margin = 0

function PANEL:Init()
  self.VBar.Paint = function() return true end
  self.VBar.btnUp.Paint = function() return true end
  self.VBar.btnDown.Paint = function() return true end
  self.VBar.btnGrip.Paint = function() return true end

  self:PerformLayout()

  function self:OnScrollbarAppear() return true end
end

function PANEL:Paint(width, height)
  theme.Hook('PaintSidebar', self, width, height)
end

function PANEL:AddPanel(panel, bCenter)
  local x, y = panel:GetPos()

  if bCenter then
    x = self:GetWide() * 0.5 - panel:GetWide() * 0.5
  end

  panel:SetPos(x, self.lastPos)

  self:AddItem(panel)

  self.lastPos = self.lastPos + self.margin + panel:GetTall()
end

function PANEL:AddSpace(px)
  self.lastPos = self.lastPos + px
end

function PANEL:Clear()
  self.BaseClass.Clear(self)
  self.lastPos = 0
end

function PANEL:SetMargin(margin)
  self.margin = tonumber(margin) or 0
end

function PANEL:add_button(text, callback)
  local button = vgui.Create('fl_button', self)
  button:SetSize(self:GetWide(), theme.GetOption('menu_sidebar_height'))
  button:SetText(text)
  button:SetDrawBackground(true)
  button:SetFont(theme.GetFont('text_normal_smaller'))
  button:SetTextAutoposition(true)
  button.DoClick = function(btn)
    btn:SetActive(true)

    if IsValid(self.prevButton) and self.prevButton != btn then
      self.prevButton:SetActive(false)
    end
     self.prevButton = btn

    if isfunction(callback) then
      callback(btn)
    end
  end

  self:AddPanel(button)

  return button
end

-- 'borrowed' from lua/vgui/dscrollpanel.lua
function PANEL:PerformLayout()
  local oldHeight = self.pnlCanvas:GetTall()
  local oldWidth = self:GetWide()
  local YPos = 0

  self:Rebuild()

  self.VBar:SetUp(self:GetTall(), self.pnlCanvas:GetTall())
  YPos = self.VBar:GetOffset()

  self.pnlCanvas:SetPos(0, YPos)
  self.pnlCanvas:SetWide(oldWidth)

  self:Rebuild()

  if oldHeight != self.pnlCanvas:GetTall() then
    self.VBar:SetScroll(self.VBar:GetScroll())
  end
end

vgui.Register('fl_sidebar', PANEL, 'DScrollPanel')
