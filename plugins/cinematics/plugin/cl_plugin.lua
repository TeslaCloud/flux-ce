--- Client side of the Cinematics plugin: the queue of cinematics, the timeline that moves the
-- letterbox bars and fades the text, and the drawing of both.
-- The cinematic on screen goes through the 'delay', 'open', 'fade_in', 'hold' and 'fade_out'
-- stages. The bars stay where they are between two queued cinematics, and the 'close' stage
-- slides them out once the queue is empty. `Cinematics.state` holds what is animated: `bars`,
-- the height of a bar as a fraction of the screen height, and `alpha`, the opacity of the text.

local math_max = math.max
local font_size = util.font_size
local get_font = Theme.get_font
local get_color = Theme.get_color
local get_option = Theme.get_option
local draw_text_outlined = draw.SimpleTextOutlined

local queue = Cinematics.queue or {}
local state = Cinematics.state or { bars = 0, alpha = 0 }
local defaults = {
  bar_size = 0.1,
  duration = 5,
  slide_time = 0.8,
  fade_time = 0.6,
  intro_duration = 6,
  intro_delay = 1.5
}
local next_stage = {
  delay = 'open',
  open = 'fade_in',
  fade_in = 'hold',
  hold = 'fade_out'
}
local text_fields = { 'text', 'title', 'subtitle' }
local fonts = {
  text = 'cinematic_caption',
  title = 'cinematic_title',
  subtitle = 'cinematic_subtitle'
}
local wrap_widths = {
  text = 0.8,
  title = 0.8,
  subtitle = 0.6
}
local fallback_font = 'DermaLarge'
local outline_color = Color(0, 0, 0)
local caption_color = Color(255, 255, 255)
local title_draw_color = Color(255, 255, 255)

Cinematics.queue = queue
Cinematics.state = state
Cinematics.defaults = defaults

--- Copies a color into one of the colors that are kept for drawing, at an opacity, so that
-- drawing a cinematic does not create colors every frame.
-- @param target [Color color to write to]
-- @param source [Color color to copy]
-- @param alpha [Number opacity from 0 to 255]
-- @return [Color the target]
local function tint(target, source, alpha)
  target.r, target.g, target.b, target.a = source.r, source.g, source.b, alpha

  return target
end

--- Converts a color that may have come over the network to an opaque Color. Other plugins
-- that show text sent by the server, such as Area Display, use it as well.
-- @param value [Color/Map color, or any table with the r, g and b fields]
-- @return [Color the color without its alpha, or nil if the value is not a color]
function Cinematics.to_color(value)
  if istable(value) and isnumber(value.r) and isnumber(value.g) and isnumber(value.b) then
    return Color(value.r, value.g, value.b)
  end
end

--- Draws lines of text one below another, aligned to a horizontal position and outlined in
-- black so that they stay readable on any background. Other plugins that draw text over the
-- screen, such as Area Display, use it as well.
-- @param lines [List<String> lines to draw]
-- @param font [String font name]
-- @param x [Number screen x the lines are aligned to]
-- @param y [Number screen y of the top of the first line]
-- @param color [Color text color, with the alpha to draw the text at]
-- @param align=TEXT_ALIGN_CENTER [Number horizontal alignment, one of the TEXT_ALIGN enums]
-- @return [Number screen y below the last line]
function Cinematics.draw_lines(lines, font, x, y, color, align)
  local line_height = font_size(font)

  align = align or TEXT_ALIGN_CENTER
  outline_color.a = color.a

  for i = 1, #lines do
    draw_text_outlined(lines[i], font, x, y, color, align, TEXT_ALIGN_TOP, 1, outline_color)

    y = y + line_height
  end

  return y
end

--- Queues a cinematic for the local player. It is played once the cinematics queued before it
-- are over. The texts are translated when the cinematic is queued, so each of them can be a
-- language phrase or plain text.
-- ```
-- Cinematics:add('The curfew has begun.')
--
-- Cinematics:add({
--   title = 'City 17',
--   subtitle = 'Trainstation',
--   color = Color(255, 220, 160),
--   duration = 8,
--   bar_size = 0.12
-- })
-- ```
-- @param cinematic [String/Map caption text or language phrase, or a table with the fields:
--   text (caption on the bottom bar), title and subtitle (drawn in the middle of the screen),
--   arguments (Map of values for the placeholders of the phrases), color (Color of the text,
--   the 'cinematic_text' theme color by default), title_color (Color of the title, the color
--   of the text by default), duration (seconds the text stays once it has faded in, the
--   'cinematic_duration' theme option by default), delay (seconds to wait before the cinematic
--   starts, 0 by default), bar_size (height of a bar as a fraction of the screen height from
--   0 to 0.5, the 'cinematic_bar_size' theme option by default) and replace (true to drop the
--   cinematic on screen and the queued ones first)]
-- @return [Map the queued cinematic, or nil if it has no text, title or subtitle]
function Cinematics:add(cinematic)
  if isstring(cinematic) then
    cinematic = { text = cinematic }
  end

  if !istable(cinematic) then return end

  local entry = {
    color = Cinematics.to_color(cinematic.color),
    title_color = Cinematics.to_color(cinematic.title_color),
    duration = math_max(tonumber(cinematic.duration) or get_option('cinematic_duration', defaults.duration), 0),
    delay = math_max(tonumber(cinematic.delay) or 0, 0),
    bar_size = math.Clamp(
      tonumber(cinematic.bar_size) or get_option('cinematic_bar_size', defaults.bar_size),
      0,
      0.5
    )
  }
  local has_text = false

  for k, v in ipairs(text_fields) do
    local value = cinematic[v]

    if isstring(value) and value != '' then
      local translated = t(value, cinematic.arguments)

      entry[v] = translated
      has_text = true
    end
  end

  if !has_text then return end

  if cinematic.replace then
    self:clear()
  end

  queue[#queue + 1] = entry

  return entry
end

--- Drops the queued cinematics and takes the one on screen away: its text disappears at once
-- and the bars slide out.
function Cinematics:clear()
  table.Empty(queue)

  self.current = nil
  state.alpha = 0

  self:set_stage(state.bars > 0 and 'close' or nil)
end

--- Checks whether the letterbox bars are on screen, which is when the plugin hides the top
-- bars, the info display and the crosshair.
-- @return [Boolean]
function Cinematics:is_active()
  return state.bars > 0
end

--- Returns the cinematic that is being played.
-- @return [Map the cinematic as queued by `Cinematics:add`, or nil if there is none]
function Cinematics:get_current()
  return self.current
end

--- Builds the intro cinematic out of the name, the description and the author of the schema
-- and queues it, unless the `GetCinematicIntroInfo` hook suppresses it.
-- @param char_id=nil [Number ID of the character that has been loaded, passed on to the hook]
-- @return [Map the queued cinematic, or nil if the intro has been suppressed or has no text]
function Cinematics:play_intro(char_id)
  local intro = {
    title = SCHEMA:get_name(),
    subtitle = SCHEMA:get_description(),
    text = 'ui.hud.cinematics.intro_credits',
    arguments = { author = SCHEMA:get_author() },
    duration = defaults.intro_duration,
    delay = defaults.intro_delay
  }

  --- Called on the client before the intro cinematic is queued, which happens when the local
  -- player loads a character for the first time since joining (unless the 'cinematic_intro'
  -- config is off) and whenever `Cinematics:play_intro` is called. Lets a schema change,
  -- replace or suppress the intro.
  -- @param intro [Map the cinematic about to be queued, with the fields that `Cinematics:add`
  --   takes: title (name of the schema), subtitle (description of the schema), text (the
  --   credits phrase), arguments (author of the schema for the phrase), duration and delay.
  --   Handlers may change it in place]
  -- @param char_id [Number ID of the character that has been loaded, nil if the intro is
  --   played on request]
  -- @return [Boolean/Map Return false to play no intro, or a table to queue that cinematic
  --   instead. Return nothing to keep `intro` and let the other handlers run]
  local result = hook.Run('GetCinematicIntroInfo', intro, char_id)

  if result == false then return end

  if istable(result) then
    intro = result
  end

  return self:add(intro)
end

--- Switches the timeline to a stage and sets up the tween or the countdown that drives it.
-- An 'open' stage that has nothing to move, because the bars already have the size the
-- cinematic asks for, turns into 'fade_in'.
-- @warning [Internal]
-- @param stage [String 'delay', 'open', 'fade_in', 'hold', 'fade_out' or 'close'; nil when
--   nothing is left to play]
function Cinematics:set_stage(stage)
  local current = self.current

  if stage == 'open' and state.bars == current.bar_size then
    stage = 'fade_in'
  end

  self.stage = stage
  self.tween = nil
  self.time_left = nil

  if stage == 'delay' then
    self.time_left = current.delay
  elseif stage == 'hold' then
    self.time_left = current.duration
  elseif stage == 'open' or stage == 'close' then
    local slide_time = math_max(get_option('cinematic_slide_time', defaults.slide_time), 0.01)

    if stage == 'open' then
      self.tween = Tween.new(slide_time, state, { bars = current.bar_size }, 'outCubic')
    else
      self.tween = Tween.new(slide_time, state, { bars = 0 }, 'inCubic')
    end
  elseif stage == 'fade_in' or stage == 'fade_out' then
    local fade_time = math_max(get_option('cinematic_fade_time', defaults.fade_time), 0.01)

    self.tween = Tween.new(fade_time, state, { alpha = stage == 'fade_in' and 255 or 0 })
  end
end

--- Takes the next cinematic off the queue and starts it. With an empty queue the bars are
-- closed if they are on screen, and the timeline stops otherwise.
-- @warning [Internal]
-- @return [Map the cinematic that has been started, or nil if the queue is empty]
function Cinematics:start_next()
  local following = table.remove(queue, 1)

  self.current = following

  if following then
    self:set_stage(following.delay > 0 and 'delay' or 'open')
  else
    self:set_stage(state.bars > 0 and 'close' or nil)
  end

  return following
end

--- Advances the timeline: updates the tween or the countdown of the current stage and moves
-- on to the next stage, the next cinematic or the closing of the bars when it is over. A
-- cinematic that is queued while the bars are closing starts right away, from where the bars
-- are, unless it has a delay: then the bars finish closing first.
-- @warning [Internal]
-- @param frame_time [Number seconds that have passed since the last call]
function Cinematics:advance(frame_time)
  local queued = queue[1]

  if !self.stage or (self.stage == 'close' and queued and queued.delay <= 0) then
    self:start_next()

    return
  end

  local finished

  if self.tween then
    finished = self.tween:update(frame_time)
  else
    self.time_left = self.time_left - frame_time
    finished = self.time_left <= 0
  end

  if !finished then return end

  local following = next_stage[self.stage]

  if following then
    self:set_stage(following)
  else
    self:start_next()
  end
end

--- Wraps the texts of a cinematic to the width of the screen and stores the lines in it.
-- @warning [Internal]
-- @param cinematic [Map the cinematic, as queued by `Cinematics:add`]
-- @param scrw [Number screen width]
function Cinematics:layout(cinematic, scrw)
  local lines = {}

  for k, v in ipairs(text_fields) do
    local text = cinematic[v]

    if text then
      local wrapped = util.wrap_text(text, get_font(fonts[v], fallback_font), scrw * wrap_widths[v]) or {}

      for k1, v1 in ipairs(wrapped) do
        wrapped[k1] = v1:strip()
      end

      lines[v] = wrapped
    end
  end

  cinematic.lines = lines
  cinematic.layout_width = scrw
end

--- Draws the letterbox bars and, once it has started to fade in, the text of the cinematic
-- that is being played: the caption in the middle of the bottom bar, the title and the
-- subtitle above the middle of the screen.
-- @param scrw [Number screen width]
-- @param scrh [Number screen height]
function Cinematics:draw(scrw, scrh)
  local bar_height = math.ceil(state.bars * scrh)

  if bar_height > 0 then
    local bar_color = get_color('cinematic_bars', color_black)

    draw.RoundedBox(0, 0, 0, scrw, bar_height, bar_color)
    draw.RoundedBox(0, 0, scrh - bar_height, scrw, bar_height, bar_color)
  end

  local current = self.current
  local alpha = state.alpha

  if !current or alpha <= 0 then return end

  if current.layout_width != scrw then
    self:layout(current, scrw)
  end

  local lines = current.lines
  local center_x = scrw * 0.5
  local text_color = current.color or get_color('cinematic_text', color_white)

  if lines.text then
    local font = get_font(fonts.text, fallback_font)
    local text_height = #lines.text * font_size(font)
    local band_height = math_max(current.bar_size * scrh, text_height + math.scale(32))

    Cinematics.draw_lines(
      lines.text,
      font,
      center_x,
      scrh - band_height * 0.5 - text_height * 0.5,
      tint(caption_color, text_color, alpha)
    )
  end

  if lines.title or lines.subtitle then
    local title_font = get_font(fonts.title, fallback_font)
    local subtitle_font = get_font(fonts.subtitle, fallback_font)
    local title_height = lines.title and #lines.title * font_size(title_font) or 0
    local subtitle_height = lines.subtitle and #lines.subtitle * font_size(subtitle_font) or 0
    local gap = (lines.title and lines.subtitle) and math.scale(8) or 0
    local y = scrh * 0.4 - (title_height + gap + subtitle_height) * 0.5

    if lines.title then
      local title_color = current.title_color or current.color or get_color('cinematic_title', color_white)

      y = Cinematics.draw_lines(
        lines.title, title_font, center_x, y, tint(title_draw_color, title_color, alpha)
      ) + gap
    end

    if lines.subtitle then
      Cinematics.draw_lines(lines.subtitle, subtitle_font, center_x, y, tint(caption_color, text_color, alpha))
    end
  end
end
