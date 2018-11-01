local PANEL = {}
PANEL.cur_amt = 160

function PANEL:Init()
  self.Image = vgui.Create('DImage', self)
  self.Image:SetSize(100, 100)
  self.Image:SetPos(0, 0)
end

function PANEL:SetImage(img)
  self.Image:SetImage(img)
end

function PANEL:Paint(w, h)
end

function PANEL:PaintOver(w, h)
  local active = self.active

  draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, (!active and self.cur_amt * 4) or 0))

  if active then
    surface.SetDrawColor(theme.get_color('accent'))
    surface.DrawOutlinedRect(0, 0, w, h)
  end
end

function PANEL:Think()
  if self:IsHovered() then
    self.cur_amt = math.Clamp(self.cur_amt - 1, 0, 40)
  else
    self.cur_amt = math.Clamp(self.cur_amt + 1, 0, 40)
  end

  self.Image:SetSize(self:GetWide(), self:GetTall())
end

vgui.Register('fl_image_button', PANEL, 'fl_button')
