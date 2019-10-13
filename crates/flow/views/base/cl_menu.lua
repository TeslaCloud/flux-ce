local PANEL = {}
PANEL.icon = nil
PANEL.icon_w = 16
PANEL.icon_h = 16

function PANEL:Init()
  self:SetFont(Theme.get_font('main_menu_small'))
  self:SetTextColor(Theme.get_color('text'))
end

function PANEL:Paint(w, h)
  local col = Theme.get_color('background')

  if self:IsHovered() then
    col = col:lighten(40)
  end

  draw.RoundedBox(0, 0, 0, w, h, col)

  if self.icon then
    draw.textured_rect(self.icon, 8, h * 0.5 - self.icon_h * 0.5, self.icon_w, self.icon_h, Color(255, 255, 255))
  end
end

function PANEL:OnMousePressed(mouse)
  if mouse == MOUSE_RIGHT or mouse == MOUSE_LEFT then
    if self.DoClick then
      self:DoClick()
    end
  end

  return DButton.OnMouseReleased(self, mouse)
end

function PANEL:set_icon(icon)
  self.icon = util.get_material(icon)
end

function PANEL:set_icon_size(w, h)
  h = h or w

  self.icon_w = w
  self.icon_h = h
end

vgui.Register('fl_menu_item', PANEL, 'DButton')

local PANEL = {}
PANEL.last = 0
PANEL.option_height = 32
PANEL.count = 0

function PANEL:PerformLayout()
  local w = 0

  -- Find the widest one
  for k, pnl in pairs(self:GetCanvas():GetChildren()) do
    pnl:InvalidateLayout()
    pnl:SizeToContentsX()

    w = math.max(w, pnl:GetWide())
  end

  w = w * 1.2

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

  self:SetKeyboardInputEnabled(true)
end

function PANEL:GetDeleteSelf()
  return true
end

function PANEL:open(x, y)
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

function PANEL:add_option(name, callback)
  local w, h = self:GetSize()

  local panel = vgui.Create('fl_menu_item', self)
  panel:SetPos(0, 0)
  panel:MoveTo(0, self.last, 0.15 * self.count)
  panel:SetSize(self:GetWide(), self.option_height)
  panel:SetTextColor(Theme.get_color('text'))
  panel:SetText(name)
  panel:MoveToBack()

  if callback then
    panel.DoClick = callback
  end

  self.last = self.last + self.option_height
  self.count = self.count + 1

  self:AddItem(panel)
  self:SetSize(w, self.last)

  return panel
end

function PANEL:add_spacer(px)
  px = px or 1

  local panel = vgui.Create('DPanel', self)
  panel:SetSize(self:GetWide(), px)
  panel:SetPos(0, 0)
  panel:MoveToBack()

  panel.Paint = function(pan, w, h)
    local wide = math.ceil(w * 0.1)

    draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('text'))
    draw.RoundedBox(0, 0, 0, wide, h, Theme.get_color('background'))
    draw.RoundedBox(0, w - wide, 0, wide, h, Theme.get_color('background'))
  end

  panel:MoveTo(0, self.last, 0.15 * self.count)

  self:AddItem(panel)

  self.last = self.last + px

  return panel
end

vgui.Register('fl_menu', PANEL, 'DScrollPanel')
