--- The clock of the tab menu (`fl_gametime_clock`): the game time with the game date below it,
-- aligned to the right. The Game Time plugin puts it at the right end of the button bar of
-- the tab menu. It takes no mouse input, so it never gets in the way of the buttons.
-- A theme can draw the clock itself with the `PaintGameTimeClock` theme hook, which receives
-- the panel, its width and its height; `get_texts` gives it the texts to draw.
-- Derives from `fl_base_panel`.

local get_font = Theme.get_font
local simple_text = draw.SimpleText
local date_color = Color(255, 255, 255, 180)

local PANEL = {}

--- Makes the clock ignore the mouse and the keyboard.
function PANEL:Init()
  self:SetMouseInputEnabled(false)
  self:SetKeyboardInputEnabled(false)
end

--- Returns the texts of the clock. They are formatted again only when a new game minute has
-- begun or when the player has switched between the 12-hour and the 24-hour clock.
-- @return [String the game time, String the game date]
function PANEL:get_texts()
  local minute = math.floor(GameTime:now() / 60)
  local twelve_hour = GameTime:uses_twelve_hour()

  if minute != self.minute or twelve_hour != self.twelve_hour then
    local timestamp = minute * 60

    self.minute = minute
    self.twelve_hour = twelve_hour
    self.time_text = GameTime:format_time(timestamp, twelve_hour)
    self.date_text = GameTime:format_date(timestamp)
  end

  return self.time_text, self.date_text
end

--- Draws the game time and the game date, unless `GameTime:should_draw_clock` says that the
-- clock is hidden or the active theme draws it in its PaintGameTimeClock hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if !GameTime:should_draw_clock() then return end

  if Theme.hook('PaintGameTimeClock', self, w, h) == nil then
    local time_text, date_text = self:get_texts()
    local time_font = get_font('main_menu_titles', 'DermaLarge')
    local date_font = get_font('text_smaller', 'DermaDefault')
    local text_color = Theme.get_color('text', color_white)
    local time_height = util.font_size(time_font)
    local y = (h - time_height - util.font_size(date_font)) * 0.5

    date_color.r, date_color.g, date_color.b = text_color.r, text_color.g, text_color.b

    simple_text(time_text, time_font, w, y, text_color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    simple_text(
      date_text,
      date_font,
      w,
      y + time_height,
      date_color,
      TEXT_ALIGN_RIGHT,
      TEXT_ALIGN_TOP
    )
  end
end

vgui.Register('fl_gametime_clock', PANEL, 'fl_base_panel')
