local PANEL = {}

function PANEL:Init()
  local padding = math.scale(4)

  self:SetTitle('Flux Frame')
  self:DockPadding(padding, Theme.get_option('frame_header_size') + padding, padding, padding)

  self.button_close = vgui.Create('fl_button', self)
  self.button_close:SetSize(math.scale_size(20, 20))
  self.button_close:SetPos(0, 0)
  self.button_close:set_icon('fa-times')
  self.button_close:set_text('')
  self.button_close:SetDrawBackground(false)
  self.button_close.DoClick = function(btn)
    self:safe_remove()
  end
end

function PANEL:Paint(w, h)
  return Theme.hook('PaintFrame', self, w, h)
end

function PANEL:Think()
  local w, h = self:GetSize()

  if IsValid(self.button_close) then
    self.button_close:SetPos(w - 20, 0)
  end

  Theme.hook('FrameThink')
end

vgui.Register('fl_frame', PANEL, 'fl_base_panel')
