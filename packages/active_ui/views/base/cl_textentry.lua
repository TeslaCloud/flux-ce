--- A text entry (`fl_text_entry`) in the theme's colors with an optional character limit.
-- Set the limit with `set_limit`; once it is reached, further input is blocked. The drawing
-- can be replaced through the `ChatboxEntryPaint` hook. Used by the chatbox and by the
-- description field of the inventory menu. Derives from `DTextEntry`.

local PANEL = {}
PANEL.limit = 0

--- Hides the language indicator, makes the entry report changes on every keystroke and
-- applies the text font and color of the theme.
function PANEL:Init()
  self:SetDrawLanguageID(false)
  self:SetUpdateOnType(true)
  self:SetFont(Theme.get_font('text_small', 'DermaDefault'))
  self:SetTextColor(Theme.get_color('text', color_white))
  self:SetCursorColor(Theme.get_color('text', color_white))
  self:SetHighlightColor(ColorAlpha(Theme.get_color('accent', color_white), 120))
end

--- Draws the field and the text through the theme's PaintTextEntry hook, unless the
-- ChatboxEntryPaint hook returns a truthy value.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  --- Lets plugins draw an `fl_text_entry` themselves.
  -- Called on the client every time such an entry is painted: for the entry of the chatbox as
  -- well as for every other one.
  -- @param panel [Panel The text entry being painted]
  -- @param x [Number Left edge of the area to draw in, always 0]
  -- @param y [Number Top edge of the area to draw in, always 0]
  -- @param w [Number Width of the entry]
  -- @param h [Number Height of the entry]
  -- @return [Boolean Return true to skip the default background and text]
  if !hook.Run('ChatboxEntryPaint', self, 0, 0, w, h) then
    Theme.hook('PaintTextEntry', self, w, h)
  end
end

--- Blocks further input once the text has reached the character limit.
-- @param char [String the character being typed]
-- @return [Boolean true to block the character, nil to allow it]
function PANEL:AllowInput(char)
  local text = self:GetValue()

  if text and text != '' then
    local limit = self:get_limit()

    if limit != 0 and utf8.len(text) >= limit then
      return true
    end
  end
end

--- Sets the maximum number of characters that can be typed into the entry.
-- @param limit=0 [Number maximum length, 0 for no limit; the absolute value is used]
function PANEL:set_limit(limit)
  self.limit = math.abs(limit or 0)
end

--- Returns the maximum number of characters that can be typed into the entry.
-- @return [Number maximum length, 0 for no limit]
function PANEL:get_limit()
  return self.limit or 0
end

vgui.Register('fl_text_entry', PANEL, 'DTextEntry')
