local PANEL = {}
PANEL.lifetime = 6
PANEL.backgroundColor = Color(0, 0, 0)
PANEL.textColor = Color(255, 255, 255)

function PANEL:Init()
  self.curAlpha = 0
  self.creationTime = CurTime()
  self.notificationText = {'NOTIFICATION'}
  self.fontSize = 0
end

function PANEL:SizeToContents()
  local bX, bY = 0, -4

  for k, v in ipairs(self.notificationText) do
    local w, h = util.text_size(v, theme.get_font('menu_normal'))

    self.fontSize = h

    if bX < w then bX = w end

    bY = bY + h + 4
  end

  self:SetSize(bX + 8, bY + 8)
end

function PANEL:SetTextColor(col)
  self.textColor = col or Color(255, 255, 255)
end

function PANEL:SetBackgroundColor(col)
  self.backgroundColor = col or Color(0, 0, 0)
end

function PANEL:SetLifetime(time)
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

function PANEL:SetText(text)
  if text:find('\n') then
    text = string.Explode('\n', text)
  else
    text = {text}
  end

  self.notificationText = text

  self:SizeToContents()
end

function PANEL:Think()
  local cur_time = CurTime()
  local frameTime = FrameTime() / 0.006

  if (cur_time - self.creationTime) > self.lifetime - 1.25 then
    self.curAlpha = self.curAlpha - 3 * frameTime
  elseif self.curAlpha < 200 then
    self.curAlpha = self.curAlpha + 4 * frameTime
  end

  if self.PostThink then
    self:PostThink()
  end
end

function PANEL:Paint(width, height)
  if !theme.hook('PaintNotificationContainer', self, width, height) then
    draw.blur_panel(self, self.curAlpha)
    draw.RoundedBox(0, 0, 0, width, height, ColorAlpha(self.backgroundColor, self.curAlpha))
  end

  if !theme.hook('PaintNotificationText', self, width, height) then
    local cur_y = 4

    for k, v in ipairs(self.notificationText) do
      draw.SimpleText(v, theme.get_font('menu_normal'), 4, cur_y, ColorAlpha(self.textColor, self.curAlpha + 55))

      cur_y = cur_y + self.fontSize + 4
    end
  end
end

vgui.Register('fl_notification', PANEL, 'EditablePanel')
