local PANEL = {}

function PANEL:Init()
  self:SetTitle('Flux Frame')
  self:SetMainColor(theme.get_color('main'))
  self:SetAccentColor(theme.get_color('accent'))

  self.btnClose = vgui.Create('fl_button', self)
  self.btnClose:SetSize(20, 20)
  self.btnClose:SetPos(0, 0)
  self.btnClose:SetIcon('fa-times')
  self.btnClose:SetText('')
  self.btnClose:SetDrawBackground(false)
  self.btnClose.DoClick = function(button)
    self:SetVisible(false)
    self:Remove()
  end
end

function PANEL:Paint(w, h)
  return theme.hook('PaintFrame', self, w, h)
end

function PANEL:Think()
  local w, h = self:GetSize()

  if IsValid(self.btnClose) then
    self.btnClose:SetPos(w - 20, 0)
  end

  theme.hook('FrameThink')
end

vgui.Register('fl_frame', PANEL, 'fl_base_panel')
