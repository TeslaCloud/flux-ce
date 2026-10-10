--- A notification popup (`fl_notification`): lines of text on a blurred background that fade
-- in and out.
-- Set it up with `set_text`, `set_text_color` and `set_background_color`, and call
-- `set_lifetime` to start the timers that slide it off the right edge of the screen and remove
-- it. Notifications are normally created through `Flux.Notification:add`, which also queues
-- and positions them. A theme can take over the drawing with its `PaintNotificationContainer`
-- and `PaintNotificationText` hooks.

local PANEL = {}
PANEL.lifetime = 6
PANEL.background_color = Color(0, 0, 0)
PANEL.text_color = Color(255, 255, 255)

--- Sets up the fade state and a placeholder text.
function PANEL:Init()
  self.cur_alpha = 0
  self.creation_time = CurTime()
  self.notification_text = { 'NOTIFICATION' }
  self.font_size = 0
end

--- Resizes the panel to fit every line of the notification text.
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

--- Fades the notification in after it is created and out shortly before its lifetime ends,
-- then calls PostThink if the panel defines it.
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

--- Draws the blurred background and the text lines, unless the theme's
-- PaintNotificationContainer or PaintNotificationText hooks return a truthy value.
-- @param width [Number panel width]
-- @param height [Number panel height]
function PANEL:Paint(width, height)
  local cur_alpha = self.cur_alpha

  if !Theme.hook('PaintNotificationContainer', self, width, height) then
    draw.blur_panel(self, cur_alpha)
    draw.RoundedBox(0, 0, 0, width, height, self.background_color:alpha(cur_alpha))
  end

  if !Theme.hook('PaintNotificationText', self, width, height) then
    local lines = self.notification_text
    local font = Theme.get_font('menu_normal')
    local color = self.text_color:alpha(self.cur_alpha + 55)
    local line_height = self.font_size + 4
    local cur_y = 4

    for i = 1, #lines do
      draw.SimpleText(lines[i], font, 4, cur_y, color)

      cur_y = cur_y + line_height
    end
  end
end

--- Sets the color of the notification text.
-- @param col=Color(255, 255, 255) [Color]
function PANEL:set_text_color(col)
  self.text_color = col or Color(255, 255, 255)
end

--- Sets the background color of the notification.
-- @param col=Color(0, 0, 0) [Color]
function PANEL:set_background_color(col)
  self.background_color = col or Color(0, 0, 0)
end

--- Sets how long the notification stays up. Starts timers that slide it off the right edge
-- of the screen 1.5 seconds before the end and remove it once the time is up.
-- @param time [Number lifetime in seconds]
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

--- Sets the notification text and resizes the panel to fit it. Newline characters split
-- the text into separate lines.
-- @param text [String]
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
