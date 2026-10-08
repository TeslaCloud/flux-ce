--- A numeric stepper (`fl_counter`): a value with a button above it to increase it, a button
-- below it to decrease it and an optional title.
-- Set the allowed range with `set_min_max` and the current value with `set_value`, read it
-- with `get_value`, and override `on_click` to react to a change or to reject it by returning
-- false. The character creation uses it to pick the skin of the model. Derives from
-- `fl_base_panel`.

local PANEL = {}
PANEL.value = 1
PANEL.max = 100
PANEL.min = 0
PANEL.font = 'flRoboto'
PANEL.color = Color('white')
PANEL.title = ''

--- Creates the title label and the increase and decrease buttons.
function PANEL:Init()
  local fa_icon_size = math.scale(16)

  self.label = vgui.Create('DLabel', self)
  self.label:SetText(self.title)
  self.label:SetFont(self.font)
  self.label:SetTextColor(self.color)

  self.inc = vgui.Create('fl_button', self)
  self.inc:set_icon('fa-chevron-up')
  self.inc:set_icon_size(fa_icon_size)
  self.inc:set_centered(true)
  self.inc:SetDrawBackground(false)
  self.inc.DoClick = function(btn)
    self:increase()
  end

  self.dec = vgui.Create('fl_button', self)
  self.dec:set_icon('fa-chevron-down')
  self.dec:set_icon_size(fa_icon_size)
  self.dec:set_centered(true)
  self.dec:SetDrawBackground(false)
  self.dec.DoClick = function(btn)
    self:decrease()
  end
end

--- Positions the label and both buttons and refreshes the enabled state of the buttons.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  self.label:SizeToContents()
  self.label:SetPos(w * 0.5 - self.label:GetWide() * 0.5, math.scale(4))

  local button_height = (h - self.label:GetTall()) * 0.5
  local offset = self.label:GetValue() != '' and self.label:GetTall() or 0

  self.inc:SetSize(w, button_height)
  self.inc:SetPos(w * 0.5 - self.inc:GetWide() * 0.5, offset + math.scale(2))
  self.inc:set_icon_size(button_height * 0.75)

  self.dec:SetSize(w, button_height)
  self.dec:SetPos(w * 0.5 - self.dec:GetWide() * 0.5, h - button_height)
  self.dec:set_icon_size(button_height * 0.75)

  self:check_buttons()
end

--- Draws the current value in the middle of the counter.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  local x, y = util.text_size(self.value, self.font)
  local offset = self.label:GetValue() != '' and self.label:GetTall() or 0
  draw.SimpleText(self.value, self.font, w * 0.5 - x * 0.5, h * 0.5 - y * 0.5 + offset * 0.5, self.color)
end

--- Sets the title shown above the counter.
-- @param text [String]
function PANEL:set_text(text)
  self.title = text

  self.label:SetText(self.title)
end

--- Sets the highest value the counter can reach.
-- @param max [Number]
function PANEL:set_max(max)
  self.max = max
  self:check_buttons()
end

--- Sets the lowest value the counter can reach.
-- @param min [Number]
function PANEL:set_min(min)
  self.min = min
  self:check_buttons()
end

--- Sets both the lowest and the highest value the counter can reach.
-- @param min [Number]
-- @param max [Number]
function PANEL:set_min_max(min, max)
  self.min = min
  self.max = max
  self:check_buttons()
end

--- Sets the current value. The value is not clamped and on_click is not called.
-- @param value [Number]
function PANEL:set_value(value)
  self.value = value
  self:check_buttons()
end

--- Sets the font of the title and the value.
-- @param font [String font name]
function PANEL:set_font(font)
  self.font = font

  self.label:SetFont(self.font)
end

--- Sets the color of the title and the value.
-- @param color [Color]
function PANEL:set_color(color)
  self.color = color

  self.label:SetTextColor(self.color)
end

--- Returns the current value of the counter.
-- @return [Number]
function PANEL:get_value()
  return self.value
end

--- Increases the value by one, clamped to the configured range. Calls on_click first and
-- leaves the value unchanged if it returns false; calls post_click afterward.
function PANEL:increase()
  local old_value = self.value
  local new_value = math.clamp(self.value + 1, self.min, self.max)

  if self:on_click(new_value, old_value) != false then
    self.value = new_value
    self:check_buttons()
    self:post_click()
  end
end

--- Decreases the value by one, clamped to the configured range. Calls on_click first and
-- leaves the value unchanged if it returns false; calls post_click afterward.
function PANEL:decrease()
  local old_value = self.value
  local new_value = math.clamp(self.value - 1, self.min, self.max)

  if self:on_click(new_value, old_value) != false then
    self.value = new_value
    self:check_buttons()
    self:post_click()
  end
end

--- Disables the increase button while the value is at the maximum and the decrease button
-- while it is at the minimum, and enables them otherwise.
function PANEL:check_buttons()
  local value = self.value

  if value == self.max then
    self.inc:set_enabled(false)
    self.inc:set_active(false)
  else
    self.inc:set_enabled(true)
    self.inc:set_active(true)
  end

  if value == self.min then
    self.dec:set_enabled(false)
    self.dec:set_active(false)
  else
    self.dec:set_enabled(true)
    self.dec:set_active(true)
  end
end

--- Called before the value changes when one of the buttons is clicked. Does nothing by
-- default; override it to react to the change, and return false from it to reject the change.
-- ```
-- self.skin.on_click = function(panel, value)
--   surface.PlaySound('buttons/blip1.wav')
--
--   self.model.Entity:SetSkin(value - 1)
-- end
-- ```
-- @param value [Number the value about to be set; the old value is passed as a second argument]
function PANEL:on_click(value)
end

--- Called after a button click has changed the value. Does nothing by default; meant to
-- be overridden.
function PANEL:post_click()
end

vgui.Register('fl_counter', PANEL, 'fl_base_panel')
