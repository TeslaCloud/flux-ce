_MsgC                       = _MsgC         or MsgC
_ErrorNoHalt                = _ErrorNoHalt  or ErrorNoHalt

local available_colors      = {
  Color(0, 0, 0),       Color(128, 0, 0),     Color(0, 128, 0),
  Color(128, 128, 0),   Color(0, 0, 128),     Color(128, 0, 128),
  Color(0, 128, 128),   Color(192, 192, 192), Color(128, 128, 128),
  Color(255, 0, 0),     Color(0, 255, 0),     Color(255, 255, 0),
  Color(0, 0, 255),     Color(255, 0, 255),   Color(0, 255, 255),
  Color(255, 255, 255), Color(0, 0, 0),       Color(0, 0, 95),
  Color(0, 0, 135),     Color(0, 0, 175),     Color(0, 0, 215),
  Color(0, 0, 255),     Color(0, 95, 0),      Color(0, 95, 95),
  Color(0, 95, 135),    Color(0, 95, 175),    Color(0, 95, 215),
  Color(0, 95, 255),    Color(0, 135, 0),     Color(0, 135, 95),
  Color(0, 135, 135),   Color(0, 135, 175),   Color(0, 135, 215),
  Color(0, 135, 255),   Color(0, 175, 0),     Color(0, 175, 95),
  Color(0, 175, 135),   Color(0, 175, 175),   Color(0, 175, 215),
  Color(0, 175, 255),   Color(0, 215, 0),     Color(0, 215, 95),
  Color(0, 215, 135),   Color(0, 215, 175),   Color(0, 215, 215),
  Color(0, 215, 255),   Color(0, 255, 0),     Color(0, 255, 95),
  Color(0, 255, 135),   Color(0, 255, 175),   Color(0, 255, 215),
  Color(0, 255, 255),   Color(95, 0, 0),      Color(95, 0, 95),
  Color(95, 0, 135),    Color(95, 0, 175),    Color(95, 0, 215),
  Color(95, 0, 255),    Color(95, 95, 0),     Color(95, 95, 95),
  Color(95, 95, 135),   Color(95, 95, 175),   Color(95, 95, 215),
  Color(95, 95, 255),   Color(95, 135, 0),    Color(95, 135, 95),
  Color(95, 135, 135),  Color(95, 135, 175),  Color(95, 135, 215),
  Color(95, 135, 255),  Color(95, 175, 0),    Color(95, 175, 95),
  Color(95, 175, 135),  Color(95, 175, 175),  Color(95, 175, 215),
  Color(95, 175, 255),  Color(95, 215, 0),    Color(95, 215, 95),
  Color(95, 215, 135),  Color(95, 215, 175),  Color(95, 215, 215),
  Color(95, 215, 255),  Color(95, 255, 0),    Color(95, 255, 95),
  Color(95, 255, 135),  Color(95, 255, 175),  Color(95, 255, 215),
  Color(95, 255, 255),  Color(135, 0, 0),     Color(135, 0, 95),
  Color(135, 0, 135),   Color(135, 0, 175),   Color(135, 0, 215),
  Color(135, 0, 255),   Color(135, 95, 0),    Color(135, 95, 95),
  Color(135, 95, 135),  Color(135, 95, 175),  Color(135, 95, 215),
  Color(135, 95, 255),  Color(135, 135, 0),   Color(135, 135, 95),
  Color(135, 135, 135), Color(135, 135, 175), Color(135, 135, 215),
  Color(135, 135, 255), Color(135, 175, 0),   Color(135, 175, 95),
  Color(135, 175, 135), Color(135, 175, 175), Color(135, 175, 215),
  Color(135, 175, 255), Color(135, 215, 0),   Color(135, 215, 95),
  Color(135, 215, 135), Color(135, 215, 175), Color(135, 215, 215),
  Color(135, 215, 255), Color(135, 255, 0),   Color(135, 255, 95),
  Color(135, 255, 135), Color(135, 255, 175), Color(135, 255, 215),
  Color(135, 255, 255), Color(175, 0, 0),     Color(175, 0, 95),
  Color(175, 0, 135),   Color(175, 0, 175),   Color(175, 0, 215),
  Color(175, 0, 255),   Color(175, 95, 0),    Color(175, 95, 95),
  Color(175, 95, 135),  Color(175, 95, 175),  Color(175, 95, 215),
  Color(175, 95, 255),  Color(175, 135, 0),   Color(175, 135, 95),
  Color(175, 135, 135), Color(175, 135, 175), Color(175, 135, 215),
  Color(175, 135, 255), Color(175, 175, 0),   Color(175, 175, 95),
  Color(175, 175, 135), Color(175, 175, 175), Color(175, 175, 215),
  Color(175, 175, 255), Color(175, 215, 0),   Color(175, 215, 95),
  Color(175, 215, 135), Color(175, 215, 175), Color(175, 215, 215),
  Color(175, 215, 255), Color(175, 255, 0),   Color(175, 255, 95),
  Color(175, 255, 135), Color(175, 255, 175), Color(175, 255, 215),
  Color(175, 255, 255), Color(215, 0, 0),     Color(215, 0, 95),
  Color(215, 0, 135),   Color(215, 0, 175),   Color(215, 0, 215),
  Color(215, 0, 255),   Color(215, 95, 0),    Color(215, 95, 95),
  Color(215, 95, 135),  Color(215, 95, 175),  Color(215, 95, 215),
  Color(215, 95, 255),  Color(215, 135, 0),   Color(215, 135, 95),
  Color(215, 135, 135), Color(215, 135, 175), Color(215, 135, 215),
  Color(215, 135, 255), Color(215, 175, 0),   Color(215, 175, 95),
  Color(215, 175, 135), Color(215, 175, 175), Color(215, 175, 215),
  Color(215, 175, 255), Color(215, 215, 0),   Color(215, 215, 95),
  Color(215, 215, 135), Color(215, 215, 175), Color(215, 215, 215),
  Color(215, 215, 255), Color(215, 255, 0),   Color(215, 255, 95),
  Color(215, 255, 135), Color(215, 255, 175), Color(215, 255, 215),
  Color(215, 255, 255), Color(255, 0, 0),     Color(255, 0, 95),
  Color(255, 0, 135),   Color(255, 0, 175),   Color(255, 0, 215),
  Color(255, 0, 255),   Color(255, 95, 0),    Color(255, 95, 95),
  Color(255, 95, 135),  Color(255, 95, 175),  Color(255, 95, 215),
  Color(255, 95, 255),  Color(255, 135, 0),   Color(255, 135, 95),
  Color(255, 135, 135), Color(255, 135, 175), Color(255, 135, 215),
  Color(255, 135, 255), Color(255, 175, 0),   Color(255, 175, 95),
  Color(255, 175, 135), Color(255, 175, 175), Color(255, 175, 215),
  Color(255, 175, 255), Color(255, 215, 0),   Color(255, 215, 95),
  Color(255, 215, 135), Color(255, 215, 175), Color(255, 215, 215),
  Color(255, 215, 255), Color(255, 255, 0),   Color(255, 255, 95),
  Color(255, 255, 135), Color(255, 255, 175), Color(255, 255, 215),
  Color(255, 255, 255), Color(8, 8, 8),       Color(18, 18, 18),
  Color(28, 28, 28),    Color(38, 38, 38),    Color(48, 48, 48),
  Color(58, 58, 58),    Color(68, 68, 68),    Color(78, 78, 78),
  Color(88, 88, 88),    Color(98, 98, 98),    Color(108, 108, 108),
  Color(118, 118, 118), Color(128, 128, 128), Color(138, 138, 138),
  Color(148, 148, 148), Color(158, 158, 158), Color(168, 168, 168),
  Color(178, 178, 178), Color(188, 188, 188), Color(198, 198, 198),
  Color(208, 208, 208), Color(218, 218, 218), Color(228, 228, 228),
  Color(238, 238, 238)
}

local n_available_colors    = #available_colors
local color_clear_sequence  = "\27[0m"
local color_start_sequence  = "\27[38;5;"
local background_sequence   = "\27[48;5;"

local function color_id_from_color(col)
  local dist, windist, ri

  for i = 1, n_available_colors do
    local color = available_colors[i]

    dist = (col.r - color.r)^2 + (col.g - color.g)^2 + (col.b - color.b)^2

    if i == 1 or dist < windist then
      windist = dist
      ri = i
    end
  end

  return tostring(ri - 1)
end

function print_colored(text, color, background_color, style)
  local color_sequence = color_clear_sequence

  if color != nil then
    if istable(color) then
      color_sequence = color_start_sequence..color_id_from_color(color).."m"
    elseif isstring(color) then
      color_sequence = color
    end
  end

  if background_color != nil then
    if istable(background_color) then
      color_sequence = color_sequence..background_sequence..color_id_from_color(background_color).."m"
    elseif isstring(background_color) then
      color_sequence = color_sequence..background_color
    end
  end

  if istable(style) then
    if style.bold == true then
      color_sequence = color_sequence.."\27[1m"
    end

    if style.dim == true or style.dimmed == true then
      color_sequence = color_sequence.."\27[2m"
    end

    if style.underline == true or style.underlined == true then
      color_sequence = color_sequence.."\27[4m"
    end

    if style.blink == true then
      color_sequence = color_sequence.."\27[5m"
    end

    if style.inverted == true or style.invert == true then
      color_sequence = color_sequence.."\27[7m"
    end

    if style.hidden == true then
      color_sequence = color_sequence.."\27[8m"
    end
  end

  Msg(color_sequence..tostring(text)..color_clear_sequence)
end

function MsgC(...)
  local this_sequence = color_clear_sequence

  for k, v in ipairs({ ... }) do
    if istable(v) then
      this_sequence = color_start_sequence..color_id_from_color(v).."m"
    else
      print_colored(tostring(v), this_sequence)
    end
  end
end

function ErrorNoHalt(msg)
  local newlines = msg:match '(\n+)$'

  if newlines then
    msg = msg:gsub('\n+$', '')
  end

  Msg('\27[41;15m\27[1m')
  _ErrorNoHalt(msg)
  Msg(color_clear_sequence..(newlines or ''))
end
