--- A notification popup (`fl_notification`): lines of text on a rounded card with an accent
-- stripe, over a blurred background, that fade in and out.
-- Set it up with `set_text`, `set_text_color` and `set_background_color`, and call
-- `set_lifetime` to start the timers that slide it off the right edge of the screen and remove
-- it. Notifications are normally created through `Flux.Notification:add`, which also queues
-- and positions them. A theme can take over the drawing with its `PaintNotificationContainer`
-- and `PaintNotificationText` hooks.

local PANEL = {}
PANEL.lifetime = 6
PANEL.background_color = nil
PANEL.text_color = nil
PANEL.padding_x = math.scale(16)
PANEL.padding_y = math.scale(10)
PANEL.stripe = math.scale(4)

--- Sets up the fade state and a placeholder text.
function PANEL:Init()
  self.cur_alpha = 0
  self.creation_time = CurTime()
  self.notification_text = { 'NOTIFICATION' }
  self.font_size = 0
end

--- Returns the color of the text: the one that was set, or the text color of the theme.
-- @return [Color]
function PANEL:get_text_color()
  return self.text_color or Theme.get_color('text', color_white)
end

--- Returns the color of the stripe and the tint of the card: the background color that was
-- set, or the accent color of the theme.
-- @return [Color]
function PANEL:get_accent_color()
  return self.background_color or Theme.get_color('accent', color_white)
end

--- Resizes the panel to fit every line of the notification text.
function PANEL:SizeToContents()
  local bx, by = 0, 0
  local font = Theme.get_font('menu_normal')
  local line_gap = math.scale(2)

  for k, v in ipairs(self.notification_text) do
    local w, h = util.text_size(v, font)

    self.font_size = h

    if bx < w then bx = w end

    by = by + h + (k > 1 and line_gap or 0)
  end

  self:SetSize(bx + self.padding_x * 2 + self.stripe, by + self.padding_y * 2)
end

--- Fades the notification in after it is created and out shortly before its lifetime ends,
-- then calls PostThink if the panel defines it.
function PANEL:Think()
  local cur_time = CurTime()
  local frame_time = FrameTime() / 0.006

  if (cur_time - self.creation_time) > self.lifetime - 1.25 then
    self.cur_alpha = math.max(self.cur_alpha - 3 * frame_time, 0)
  elseif self.cur_alpha < 255 then
    self.cur_alpha = math.min(self.cur_alpha + 6 * frame_time, 255)
  end

  if self.PostThink then
    self:PostThink()
  end
end

--- Draws the blurred card with its accent stripe and the text lines, unless the theme's
-- PaintNotificationContainer or PaintNotificationText hooks return a truthy value.
-- @param width [Number panel width]
-- @param height [Number panel height]
function PANEL:Paint(width, height)
  local cur_alpha = self.cur_alpha
  local fraction = cur_alpha / 255
  local radius = Theme.get_option('corner_radius', math.scale(6))
  local accent = self:get_accent_color()

  if !Theme.hook('PaintNotificationContainer', self, width, height) then
    local surface_color = Theme.get_color('surface', Color(30, 33, 44))
    local border = Theme.get_color('border', Color(74, 80, 104))

    draw.blur_panel(self, cur_alpha)
    draw.RoundedBox(radius, 0, 0, width, height, ColorAlpha(border, border.a * fraction))
    draw.RoundedBox(radius - 1, 1, 1, width - 2, height - 2, ColorAlpha(surface_color, 240 * fraction))
    draw.RoundedBoxEx(
      radius - 1,
      1,
      1,
      self.stripe,
      height - 2,
      ColorAlpha(accent, 255 * fraction),
      true,
      false,
      true,
      false
    )
  end

  if !Theme.hook('PaintNotificationText', self, width, height) then
    local lines = self.notification_text
    local font = Theme.get_font('menu_normal')
    local color = ColorAlpha(self:get_text_color(), cur_alpha)
    local line_height = self.font_size + math.scale(2)
    local cur_y = self.padding_y
    local x = self.stripe + self.padding_x

    for i = 1, #lines do
      draw.SimpleText(lines[i], font, x, cur_y, color)

      cur_y = cur_y + line_height
    end
  end
end

--- Sets the color of the notification text.
-- @param col=nil [Color the text color of the theme when omitted]
function PANEL:set_text_color(col)
  self.text_color = col
end

--- Sets the color of the stripe of the notification.
-- @param col=nil [Color the accent color of the theme when omitted]
function PANEL:set_background_color(col)
  self.background_color = col
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
