--- The display styles that come with Area Display: 'fade', 'typewriter' and 'cinematic'.
-- They are registered on both realms, so that the server knows which styles the Area Tool
-- may give to an area; their drawing code only exists on the client.

local fade_style = { name = 'ui.area_display.styles.fade' }
local typewriter_style = { name = 'ui.area_display.styles.typewriter' }
local cinematic_style = { name = 'ui.area_display.styles.cinematic' }

if CLIENT then
  local fallback_font = 'DermaLarge'

  --- Wraps the text of a notice to a part of the screen width and stores the lines in it.
  -- @param display [Map the notice; its `lines` and `layout_width` fields are set]
  -- @param font [String font the text is drawn with]
  -- @param scrw [Number screen width the layout is made for]
  -- @param fraction [Number how much of the screen width a line may take, from 0 to 1]
  -- @return [List<String> the lines]
  local function wrap_lines(display, font, scrw, fraction)
    local lines = util.wrap_text(display.text, font, scrw * fraction) or {}

    for k, v in ipairs(lines) do
      lines[k] = v:strip()
    end

    display.lines = lines
    display.layout_width = scrw

    return lines
  end

  --- Draws lines of text one below another, outlined in black so that they stay readable on
  -- any background. The Cinematics plugin draws them with `Cinematics.draw_lines` whenever it
  -- is loaded; the code here is only the fallback for a server without it.
  -- @param lines [List<String> lines to draw]
  -- @param font [String font name]
  -- @param x [Number screen x the lines are aligned to]
  -- @param y [Number screen y of the top of the first line]
  -- @param color [Color text color, with the alpha to draw the text at]
  -- @param align [Number horizontal alignment, one of the TEXT_ALIGN enums]
  -- @return [Number height the lines took]
  local function draw_lines(lines, font, x, y, color, align)
    if Cinematics and isfunction(Cinematics.draw_lines) then
      return Cinematics.draw_lines(lines, font, x, y, color, align) - y
    end

    local line_height = util.font_size(font)
    local outline_color = Color(0, 0, 0, color.a)

    for k, v in ipairs(lines) do
      draw.SimpleTextOutlined(v, font, x, y, color, align, TEXT_ALIGN_TOP, 1, outline_color)

      y = y + line_height
    end

    return #lines * line_height
  end

  --- Draws the notice as a title in the upper part of the screen, centered horizontally.
  -- @param display [Map the notice]
  -- @param alpha [Number opacity of the notice, from 0 to 255]
  -- @param scrw [Number screen width]
  -- @param scrh [Number screen height]
  -- @param offset [Number height taken by the notices of this style drawn before this one]
  -- @return [Number height the notice took]
  function fade_style:draw(display, alpha, scrw, scrh, offset)
    local font = Theme.get_font('area_display_title', fallback_font)

    if display.layout_width != scrw then
      wrap_lines(display, font, scrw, 0.8)
    end

    local color = display.color or Theme.get_color('area_display_text', color_white)
    local height = draw_lines(
      display.lines,
      font,
      scrw * 0.5,
      scrh * 0.2 + offset,
      color:alpha(alpha),
      TEXT_ALIGN_CENTER
    )

    return height + math.scale(12)
  end

  --- Wraps the text of the notice and splits its lines into the characters to type out.
  -- @param display [Map the notice; its `lines`, `line_chars` and `char_count` fields are set]
  -- @param scrw [Number screen width the layout is made for]
  function typewriter_style:layout(display, scrw)
    local font = Theme.get_font('area_display_typewriter', fallback_font)
    local lines = wrap_lines(display, font, scrw, 0.6)
    local line_chars = {}
    local char_count = 0

    for k, v in ipairs(lines) do
      local chars = {}

      for char in v:gmatch(utf8.charpattern) do
        table.insert(chars, char)
      end

      line_chars[k] = chars
      char_count = char_count + #chars
    end

    display.line_chars = line_chars
    display.char_count = char_count
    display.typed = nil
  end

  --- Prepares the notice for typing: it appears at once instead of fading in, and stays for
  -- as long as it takes to type it out on top of its usual time.
  -- @param display [Map the notice]
  function typewriter_style:start(display)
    display.type_interval = math.max(
      Theme.get_option('area_display_type_interval', AreaDisplay.defaults.type_interval),
      0.01
    )

    self:layout(display, ScrW())

    display.fade_in = 0
    display.hold = display.hold + display.char_count * display.type_interval
  end

  --- Updates the part of the text that has been typed out so far and plays the typing sound
  -- if a new character other than a space has appeared.
  -- @param display [Map the notice; its `typed` and `typed_lines` fields are set]
  -- @param typed [Number how many characters of the text are typed out]
  function typewriter_style:advance(display, typed)
    local lines = {}
    local remaining = typed
    local last_char

    for k, chars in ipairs(display.line_chars) do
      if remaining <= 0 then break end

      local amount = math.min(#chars, remaining)

      lines[k] = table.concat(chars, '', 1, amount)
      last_char = chars[amount]
      remaining = remaining - amount
    end

    if typed < display.char_count then
      local current = math.max(#lines, 1)

      lines[current] = (lines[current] or '')..'_'
    end

    if typed > (display.typed or 0) and last_char and last_char != ' ' then
      local path = Theme.get_sound('area_display_type', AreaDisplay.defaults.type_sound)
      local volume = math.Clamp(
        Theme.get_option('area_display_type_volume', AreaDisplay.defaults.type_volume),
        0,
        1
      )

      if isstring(path) and path != '' and volume > 0 and IsValid(PLAYER) then
        PLAYER:EmitSound(path, 75, 100, volume)
      end
    end

    display.typed = typed
    display.typed_lines = lines
  end

  --- Draws the part of the notice that has been typed out so far at the left side of the
  -- screen, below its middle.
  -- @param display [Map the notice]
  -- @param alpha [Number opacity of the notice, from 0 to 255]
  -- @param scrw [Number screen width]
  -- @param scrh [Number screen height]
  -- @param offset [Number height taken by the notices of this style drawn before this one]
  -- @return [Number height the notice took]
  function typewriter_style:draw(display, alpha, scrw, scrh, offset)
    if display.layout_width != scrw then
      self:layout(display, scrw)
    end

    local typed = math.Clamp(
      math.floor((CurTime() - display.start_time) / display.type_interval),
      0,
      display.char_count
    )

    if typed != display.typed then
      self:advance(display, typed)
    end

    local font = Theme.get_font('area_display_typewriter', fallback_font)
    local color = display.color or Theme.get_color('area_display_text', color_white)

    draw_lines(
      display.typed_lines,
      font,
      scrw * 0.08,
      scrh * 0.6 + offset,
      color:alpha(alpha),
      TEXT_ALIGN_LEFT
    )

    return #display.lines * util.font_size(font) + math.scale(12)
  end

  --- Checks whether the Cinematics plugin is loaded. The default style is used if it is not.
  -- @return [Boolean]
  function cinematic_style:is_available()
    return istable(Cinematics) and isfunction(Cinematics.add)
  end

  --- Queues the notice as a caption of the Cinematics plugin, which draws it between its
  -- letterbox bars.
  -- @param display [Map the notice]
  -- @return [Boolean always false: the notice is not drawn by Area Display]
  function cinematic_style:start(display)
    Cinematics:add({
      text = display.text,
      color = display.color,
      duration = display.duration
    })

    return false
  end
end

AreaDisplay:register_style('fade', fade_style)
AreaDisplay:register_style('typewriter', typewriter_style)
AreaDisplay:register_style('cinematic', cinematic_style)
