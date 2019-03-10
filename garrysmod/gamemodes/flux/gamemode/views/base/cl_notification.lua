local PANEL = {}
PANEL.lifetime = 6
PANEL.background_color = Color(0, 0, 0)
PANEL.text_color = Color(255, 255, 255)

function PANEL:Init()
  self.cur_alpha = 0
  self.creation_time = CurTime()
  self.notification_text = { 'NOTIFICATION' }
  self.font_size = 0
end

function PANEL:SizeToContents()
  local bx, by = 0, -4

  for k, v in ipairs(self.notification_text) do
    local w, h = util.text_size(v, Theme.get_font('menu_normal'))

    self.font_size = h

    if bx < w then bx = w end

    by = by + h + 4
  end

  self:SetSize(bx + 8, by + 8)
end

function PANEL:Think()
  local cur_time = CurTime()
  local frame_time = FrameTime() / 0.006

  if (cur_time - self.creation_time) > self.lifetime - 1.25 then
    self.cur_alpha = self.cur_alpha - 3 * frame_time
  elseif self.cur_alpha < 200 then
    self.cur_alpha = self.cur_alpha + 4 * frame_time
  end

  if self.PostThink then
    self:PostThink()
  end
end

function PANEL:Paint(width, height)
  if !Theme.hook('PaintNotificationContainer', self, width, height) then
    draw.blur_panel(self, self.cur_alpha)
    draw.RoundedBox(0, 0, 0, width, height, self.background_color:alpha(self.cur_alpha))
  end

  if !Theme.hook('PaintNotificationText', self, width, height) then
    local cur_y = 4

    for k, v in ipairs(self.notification_text) do
      draw.SimpleText(v, Theme.get_font('menu_normal'), 4, cur_y, self.text_color:alpha(self.cur_alpha + 55))

      cur_y = cur_y + self.font_size + 4
    end
  end
end

function PANEL:set_text_color(col)
  self.text_color = col or Color(255, 255, 255)
end

function PANEL:set_background_color(col)
  self.background_color = col or Color(0, 0, 0)
end

function PANEL:set_lifetime(time)
  timer.Simple(time, function()
    if IsValid(self) then
      self:safe_remove()
    end
  end)

  timer.Simple(time - 1.5, function()
    if IsValid(self) then
      local x, y = self:GetPos()
      self:MoveTo(ScrW(), y, 0.5)
    end
  end)

  self.lifetime = time
end

function PANEL:set_text(text)
  if text:find('\n') then
    text = text:split('\n')
  else
    text = { text }
  end

  self.notification_text = text

  self:SizeToContents()
end

vgui.Register('fl_notification', PANEL, 'EditablePanel')
