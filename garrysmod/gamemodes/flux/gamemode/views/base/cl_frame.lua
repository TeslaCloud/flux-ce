local PANEL = {}

function PANEL:Init()
  self:SetTitle('Flux Frame')
  self:SetMainColor(theme.get_color('main'))
  self:SetAccentColor(theme.get_color('accent'))

  self.button_close = vgui.Create('fl_button', self)
  self.button_close:SetSize(20, 20)
  self.button_close:SetPos(0, 0)
  self.button_close:SetIcon('fa-times')
  self.button_close:SetText('')
  self.button_close:SetDrawBackground(false)
  self.button_close.DoClick = function(button)
    self:SetVisible(false)
    self:Remove()
  end
end

function PANEL:Paint(w, h)
  return theme.hook('PaintFrame', self, w, h)
end

function PANEL:Think()
  local w, h = self:GetSize()

  if IsValid(self.button_close) then
    self.button_close:SetPos(w - 20, 0)
  end

  theme.hook('FrameThink')
end

vgui.Register('fl_frame', PANEL, 'fl_base_panel')
