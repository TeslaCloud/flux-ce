local PANEL = {}

PANEL.title = ''
PANEL.icon = false
PANEL.autopos = true
PANEL.cur_amt = 0
PANEL.active = false
PANEL.icon_size = nil
PANEL.icon_left = true
PANEL.enabled = true
PANEL.centered = false

function PANEL:Paint(w, h)
  theme.hook('PaintButton', self, w, h)
end

function PANEL:Think()
  self.BaseClass.Think(self)

  local frame_time = FrameTime() / 0.006

  if self:IsHovered() then
    self.cur_amt = math.Clamp(self.cur_amt + 1 * frame_time, 0, 40)
  else
    self.cur_amt = math.Clamp(self.cur_amt - 1 * frame_time, 0, 40)
  end

  if !self.icon_size_override then
    self.icon_size = self:GetTall() - 6
  end
end

function PANEL:OnMousePressed(key)
  if key == MOUSE_LEFT then
    if self.DoClick then
      self:DoClick()
    end
  elseif key == MOUSE_RIGHT then
    if self.DoRightClick then
      self:DoRightClick()
    end
  end
end

function PANEL:SizeToContents()
  local w, h = util.text_size(self.title, self.font)
  local add = 0

  if self.icon then
    add = h * 1.5 - 2
  end

  self:SetSize(w * 1.15 + add, h * 1.5)
end

function PANEL:set_centered(centered)
  self.centered = centered
end

function PANEL:set_active(active)
  self.active = active
end

function PANEL:is_active()
  return self.active
end

function PANEL:toggle()
  self.active = !self.active
end

function PANEL:set_enabled(enabled)
  self.enabled = enabled
  self.text_color_override = (!enabled and theme.get_color('text'):darken(50)) or nil

  self:SetMouseInputEnabled(enabled)
end

function PANEL:set_text_color(color)
  self.text_color_override = color
end

function PANEL:set_text(new_text)
  return self:SetTitle(new_text)
end

function PANEL:set_text_offset(pos)
  self.text_offset = pos or 0
end

function PANEL:get_text_offset()
  return self.text_offset or 0
end

function PANEL:set_icon(icon, right)
  self.icon = tostring(icon) or false

  if right then
    self.icon_left = false
  end
end

function PANEL:set_icon_size(size)
  self.icon_size = size
  self.icon_size_override = true
end

function PANEL:set_text_autoposition(autopos)
  self.autopos = autopos
end

vgui.Register('fl_button', PANEL, 'fl_base_panel')
