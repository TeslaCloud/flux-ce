--- The standard Flux button (`fl_button`): a title with an optional FontAwesome icon, drawn by
-- the active theme's `PaintButton` hook.
-- Set it up with `set_text`, `set_icon`, `set_icon_size`, `set_centered` and
-- `set_text_offset`, and assign `DoClick` or `DoRightClick` to handle clicks. `set_active`
-- marks the button as selected, `set_enabled(false)` darkens its text and blocks mouse input,
-- and `set_background_color` and `set_draw_outline` control what is drawn behind the title.
-- Derives from `fl_base_panel`.

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
PANEL.background_color = nil
PANEL.draw_outline = false

--- Delegates drawing of the button to the active theme's PaintButton hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('PaintButton', self, w, h)
end

--- Updates the hover fade amount and, unless an icon size was set explicitly, fits the icon
-- size to the height of the button.
function PANEL:Think()
  self.BaseClass.Think(self)

  local frame_time = FrameTime() / 0.006

  if self:IsHovered() then
    self.cur_amt = math.Clamp(self.cur_amt + 1 * frame_time, 0, 20)
  else
    self.cur_amt = math.Clamp(self.cur_amt - 1 * frame_time, 0, 20)
  end

  if !self.icon_size_override then
    self.icon_size = self:GetTall() - 6
  end
end

--- Calls DoClick on a left click and DoRightClick on a right click, if they are defined.
-- @param key [Number mouse button code, one of the MOUSE_ enums]
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

--- Sets the width of the button to fit its title, icon and text offset.
function PANEL:SizeToContentsX()
  local w, h = util.text_size(self.title, self.font)
  local offset = self.text_offset or 0

  if self.icon then
    w = w + FontAwesome:get_icon_size(self.icon, self.icon_size) * 1.5
  end

  w = w + offset * 2

  self:SetWide(w)
end

--- Sets the height of the button to the height of its title text.
function PANEL:SizeToContentsY()
  local w, h = util.text_size(self.title, self.font)

  self:SetTall(h)
end

--- Resizes the button to fit its title and icon in both dimensions.
function PANEL:SizeToContents()
  self:SizeToContentsX()
  self:SizeToContentsY()
end

--- Sets whether the title is centered horizontally instead of placed at the text offset.
-- @param centered [Boolean]
function PANEL:set_centered(centered)
  self.centered = centered
end

--- Sets the active (selected) state of the button, which themes use when painting it.
-- @param active [Boolean]
function PANEL:set_active(active)
  self.active = active
end

--- Checks whether the button is in the active (selected) state.
-- @return [Boolean]
function PANEL:is_active()
  return self.active
end

--- Flips the active state of the button.
function PANEL:toggle()
  self.active = !self.active
end

--- Enables or disables the button. A disabled button ignores mouse input and gets darkened
-- text; enabling it clears any text color set with set_text_color.
-- @param enabled [Boolean]
function PANEL:set_enabled(enabled)
  self.enabled = enabled
  self.text_color_override = (!enabled and Theme.get_color('text'):darken(50)) or nil

  self:SetMouseInputEnabled(enabled)
end

--- Overrides the color of the title and the icon.
-- @param color [Color the color to use, or nil to go back to the theme's text color]
function PANEL:set_text_color(color)
  self.text_color_override = color
end

--- Sets the title displayed on the button.
-- @param new_text [String]
function PANEL:set_text(new_text)
  return self:SetTitle(new_text)
end

--- Sets the horizontal offset of the title from the left edge of the button.
-- @param pos=0 [Number offset in pixels]
function PANEL:set_text_offset(pos)
  self.text_offset = pos or 0
end

--- Returns the horizontal offset of the title, which is always 0 for centered buttons.
-- @return [Number offset in pixels]
function PANEL:get_text_offset()
  return !self.centered and self.text_offset or 0
end

--- Sets the FontAwesome icon displayed next to the title.
-- @param icon [String FontAwesome icon ID, e.g. 'fa-times']
-- @param right=false [Boolean place the icon to the right of the title instead of the left]
function PANEL:set_icon(icon, right)
  self.icon = tostring(icon) or false

  if right then
    self.icon_left = false
  end
end

--- Sets a fixed icon size and stops the icon from being resized to fit the button height.
-- @param size [Number icon size in pixels]
function PANEL:set_icon_size(size)
  self.icon_size = size
  self.icon_size_override = true
end

--- Sets the text autoposition flag. The flag is only stored; nothing in the framework
-- currently reads it.
-- @param autopos [Boolean]
function PANEL:set_text_autoposition(autopos)
  self.autopos = autopos
end

--- Sets the background color of the button. It is only drawn while the panel's
-- draw_background field is enabled.
-- @param color [Color the color to use, or nil for no background fill]
function PANEL:set_background_color(color)
  self.background_color = color
end

--- Returns the background color of the button.
-- @return [Color the background color, or nil if none is set]
function PANEL:get_background_color()
  return self.background_color
end

--- Sets whether a border in the theme's outline color is drawn around the button.
-- @param should_draw [Boolean]
function PANEL:set_draw_outline(should_draw)
  self.draw_outline = should_draw
end

--- Checks whether the outline of the button is drawn.
-- @return [Boolean]
function PANEL:get_draw_outline()
  return self.draw_outline
end

vgui.Register('fl_button', PANEL, 'fl_base_panel')
