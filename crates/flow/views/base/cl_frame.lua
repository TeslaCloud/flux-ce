local PANEL = {}
PANEL.draggable = true

function PANEL:Init()
  local padding = math.scale(4)

  self:SetTitle('Flux Frame')
  self:DockPadding(padding, Theme.get_option('frame_header_size') + padding, padding, padding)

  self.button_close = vgui.Create('fl_button', self)
  self.button_close:SetSize(math.scale_size(20, 20))
  self.button_close:SetPos(0, 0)
  self.button_close:set_icon('fa-times')
  self.button_close:set_text('')
  self.button_close:set_centered(true)
  self.button_close:SetDrawBackground(false)
  self.button_close.DoClick = function(btn)
    self:safe_remove()
  end
end

function PANEL:PerformLayout(w, h)
  self.button_close:SetPos(w - math.scale_x(20), 0)
end

function PANEL:Paint(w, h)
  return Theme.hook('PaintFrame', self, w, h)
end

function PANEL:Think()
  if self.dragging then
    local scrw, scrh = ScrW(), ScrH()
    local mouse_x = math.clamp(gui.MouseX(), 1, scrw - 1)
    local mouse_y = math.clamp(gui.MouseY(), 1, scrh - 1)
    local x, y = mouse_x - self.dragging[1], mouse_y - self.dragging[2]

    x = math.clamp(x, 0, scrw - self:GetWide())
    y = math.clamp(y, 0, scrh - self:GetTall())

    self:SetPos(x, y)
  end

  Theme.hook('FrameThink')
end

function PANEL:OnMousePressed()
  if self:is_draggable() then
    self.dragging = { gui.MouseX() - self.x, gui.MouseY() - self.y }
    self:MouseCapture(true)
  end
end

function PANEL:OnMouseReleased()
  if self:is_draggable() then
    self.dragging = nil
    self:MouseCapture(false)
  end
end

function PANEL:set_draggable(bool)
  self.draggable = true
end

function PANEL:is_draggable()
  return self.draggable
end

vgui.Register('fl_frame', PANEL, 'fl_base_panel')
