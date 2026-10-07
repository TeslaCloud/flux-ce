
local PANEL = {}
PANEL.limit = 0

--- Hides the language indicator and makes the entry report changes on every keystroke.
function PANEL:Init()
  self:SetDrawLanguageID(false)
  self:SetUpdateOnType(true)
end

--- Draws the background and the text in theme colors, unless the ChatboxEntryPaint hook
-- returns a truthy value.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if !hook.run('ChatboxEntryPaint', self, 0, 0, w, h) then
    draw.RoundedBox(2, 0, 0, w, h, Theme.get_color('background'))

    self:DrawTextEntryText(Theme.get_color('text'), Theme.get_color('accent'), Theme.get_color('text'))
  end
end

--- Blocks further input once the text has reached the character limit.
-- @param char [String the character being typed]
-- @return [Boolean true to block the character, nil to allow it]
function PANEL:AllowInput(char)
  local text = self:GetValue()

  if text and text != '' then
    if self:get_limit() != 0 and utf8.len(text) >= self:get_limit() then
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
