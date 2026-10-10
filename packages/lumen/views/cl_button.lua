--- The button of Lumen (`lumen_button`), behind the `button` element. A text panel that takes
-- the mouse, lightens when hovered, is drawn with the `active_background` of its style when
-- `set_active` is on, is dimmed and ignores clicks when `set_enabled` is off, and can show a
-- FontAwesome icon in front of its text with `set_icon`. Fires the `on_press` and
-- `on_right_press` props when a button is released over it. Derives from `lumen_text`.

local math_clamp = math.Clamp
local math_floor = math.floor
local math_max   = math.max

local PANEL = {}
PANEL.enabled = true
PANEL.active = false
PANEL.icon = nil
PANEL.hover_amount = 0

--- Takes the mouse and shows the hand cursor.
function PANEL:Init()
  self:SetMouseInputEnabled(true)
  self:SetCursor('hand')
end

--- Enables or disables the button. A disabled button ignores clicks and draws its text in
-- the `disabled_color` of its style, or darkened.
-- @param enabled [Boolean]
function PANEL:set_enabled(enabled)
  self.enabled = enabled != false
end

--- Checks whether the button is enabled.
-- @return [Boolean]
function PANEL:is_enabled()
  return self.enabled
end

--- Marks the button as selected, which draws it with the `active_background` of its style.
-- @param active [Boolean]
function PANEL:set_active(active)
  self.active = active == true
end

--- Checks whether the button is marked as selected.
-- @return [Boolean]
function PANEL:is_active()
  return self.active
end

--- Sets the FontAwesome icon drawn in front of the text.
-- @param icon [String icon ID such as 'fa-times', or nil for none]
function PANEL:set_icon(icon)
  if icon == self.icon then return end

  self.icon = icon

  self:InvalidateLayout()
  self:InvalidateParent()
end

--- Returns the size of the icon, which is the height of a line of the font.
-- @return [Number]
function PANEL:get_icon_font_size()
  return util.font_size(self:get_font())
end

--- Returns the width the icon and the space after it take up.
-- @return [Number 0 without an icon or without the FontAwesome package]
function PANEL:get_icon_size()
  if !self.icon or !FontAwesome then return 0 end

  local size = self:get_icon_font_size()
  local w = FontAwesome:get_icon_size(self.icon, size)

  if self.text == '' then
    return w
  end

  return w + math_floor(size * 0.5)
end

--- Fades the hover highlight in and out.
function PANEL:Think()
  local step = FrameTime() * 8

  if self:IsHovered() and self.enabled then
    self.hover_amount = math_clamp(self.hover_amount + step, 0, 1)
  else
    self.hover_amount = math_clamp(self.hover_amount - step, 0, 1)
  end
end

--- Returns the background to draw right now: the active, hovered or plain one of the style.
-- @return [Color, or nil for none]
function PANEL:get_background()
  local style = Lumen.Layout.style_of(self)
  local background = style.background

  if self.active and style.active_background then
    return style.active_background
  end

  if !background then return nil end

  if self.hover_amount > 0 then
    local hover = style.hover_background or background:lighten(20)

    return Color(
      background.r + (hover.r - background.r) * self.hover_amount,
      background.g + (hover.g - background.g) * self.hover_amount,
      background.b + (hover.b - background.b) * self.hover_amount,
      background.a + (hover.a - background.a) * self.hover_amount
    )
  end

  return background
end

--- Returns the color of the text right now.
-- @return [Color]
function PANEL:get_current_text_color()
  local color = self:get_text_color()

  if !self.enabled then
    local style = Lumen.Layout.style_of(self)

    return style.disabled_color or color:darken(60)
  end

  return color
end

--- Draws the background, the icon and the text.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Lumen.paint_box(self, w, h, self:get_background())

  local color = self:get_current_text_color()
  local icon_w = self:get_icon_size()

  if icon_w > 0 then
    local style = Lumen.Layout.style_of(self)
    local pad = style.padding
    local size = self:get_icon_font_size()
    local inner_left = pad.left + icon_w
    local inner_w = w - inner_left - pad.right
    local text_w = self:measure_lines(self.lines or { self.text })
    local x = pad.left

    if style.text_align == 'center' then
      x = math_max(inner_left + inner_w * 0.5 - text_w * 0.5 - icon_w, pad.left)
    elseif style.text_align == 'right' then
      x = math_max(w - pad.right - text_w - icon_w, pad.left)
    end

    FontAwesome:draw(self.icon, math_floor(x), math_floor(h * 0.5), size, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end

  self:draw_text(w, h, color, icon_w)
end

--- Remembers that a button went down on the panel.
-- @param code [Number mouse button]
function PANEL:OnMousePressed(code)
  if !self.enabled then return end

  self.pressed = code
end

--- Fires the press handler of the button that went down on the panel.
-- @param code [Number mouse button]
function PANEL:OnMouseReleased(code)
  if !self.enabled or self.pressed != code then
    self.pressed = nil

    return
  end

  self.pressed = nil

  Lumen.press_handler(self, code)
end

--- Forgets a press when the cursor leaves the panel.
function PANEL:OnCursorExited()
  self.pressed = nil
end

vgui.Register('lumen_button', PANEL, 'lumen_text')
