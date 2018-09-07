local PANEL = {}
PANEL.icon = nil
PANEL.iconW = 16
PANEL.iconH = 16

function PANEL:GetDeleteSelf()
  return true
end

function PANEL:Init()
  self:SetFont(theme.GetFont("Text_Small"))
  self:SetTextColor(theme.GetColor("Text"))
end

function PANEL:Paint(w, h)
  local col = theme.GetColor("Background")

  if (self:IsHovered()) then
    col = col:lighten(40)
  end

  draw.RoundedBox(0, 0, 0, w, h, col)

  if (self.icon) then
    draw.TexturedRect(self.icon, 8, h * 0.5 - self.iconH * 0.5, self.iconW, self.iconH, Color(255, 255, 255))
  end
end

function PANEL:OnMousePressed(mouse)
  if (mouse == MOUSE_RIGHT or mouse == MOUSE_LEFT) then
    if (self.DoClick) then
      self:DoClick()
    end
  end

  return DButton.OnMouseReleased(self, mouse)
end

function PANEL:SetIcon(icon)
  self.icon = util.get_material(icon)
end

function PANEL:SetIconSize(w, h)
  h = h or w

  self.iconW = w
  self.iconH = h
end

vgui.Register("flMenuItem", PANEL, "DButton")

local PANEL = {}
PANEL.last = 0
PANEL.optionHeight = 32
PANEL.count = 0

function PANEL:GetDeleteSelf()
  return true
end

function PANEL:AddOption(name, callback)
  local w, h = self:GetSize()

  local panel = vgui.Create("flMenuItem", self)
  panel:SetPos(0, 0)
  panel:MoveTo(0, self.last, 0.15 * self.count)
  panel:SetSize(self:GetWide(), self.optionHeight)
  panel:SetTextColor(theme.GetColor("Text"))
  panel:SetText(name)
  panel:MoveToBack()

  if (callback) then
    panel.DoClick = callback
  end

  print(panel.DoClick, callback)

  self.last = self.last + self.optionHeight
  self.count = self.count + 1

  self:AddItem(panel)
  self:SetSize(w, self.last)

  return panel
end

function PANEL:AddSpacer(px)
  px = px or 1

  local panel = vgui.Create("DPanel", self)
  panel:SetSize(self:GetWide(), px)
  panel:SetPos(0, 0)
  panel:MoveToBack()

  panel.Paint = function(pan, w, h)
    local wide = math.ceil(w * 0.1)

    draw.RoundedBox(0, 0, 0, w, h, theme.GetColor("Text"))
    draw.RoundedBox(0, 0, 0, wide, h, theme.GetColor("Background"))
    draw.RoundedBox(0, w - wide, 0, wide, h, theme.GetColor("Background"))
  end

  panel:MoveTo(0, self.last, 0.15 * self.count)

  self:AddItem(panel)

  self.last = self.last + px

  return panel
end

function PANEL:PerformLayout()
  local w = 128

  -- Find the widest one
  for k, pnl in pairs(self:GetCanvas():GetChildren()) do
    if (pnl.PerformLayout) then
      pnl:PerformLayout()
    end

    w = math.max(w, pnl:GetWide())
  end

  self:SetWide(w)

  local y = 0

  for k, pnl in pairs(self:GetCanvas():GetChildren()) do
    pnl:SetWide(w)
    pnl:InvalidateLayout(true)
    pnl:MoveToFront()

    y = y + pnl:GetTall()
  end

  self:SetTall(math.min(y, ScrH() * 0.75))

  DScrollPanel.PerformLayout(self)
end

function PANEL:Open(x, y)
  x = x or gui.MouseX()
  y = y or gui.MouseY()

  RegisterDermaMenuForClose(self)

  self:SetWide(200)
  self:PerformLayout()

  self:SetPos(x, y)

  self:MakePopup()
  self:SetVisible(true)
  self:SetKeyboardInputEnabled(false)
  self:SetMouseInputEnabled(true)
  self:RequestFocus()

  return self
end

vgui.Register("flMenu", PANEL, "DScrollPanel")
