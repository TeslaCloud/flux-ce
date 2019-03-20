_MsgC                       = _MsgC         or MsgC
_ErrorNoHalt                = _ErrorNoHalt  or ErrorNoHalt

local available_colors      = {
  "\27[0;30m", "\27[0;34m", "\27[0;32m",
  "\27[0;36m", "\27[0;31m", "\27[0;35m",
  "\27[1;33m", "\27[0;37m", "\27[0;30m",
  "\27[1;34m", "\27[0;34m", "\27[1;32m",
  "\27[1;36m", "\27[1;31m", "\27[1;35m"
  "\27[1;33m", "\27[1;37m", "\27[0m"
}

local color_map             = {
  Color(0, 0, 0),       Color(0, 0, 127),     Color(0, 127, 0),
  Color(0, 127, 127),   Color(127, 0, 0),     Color(127, 0, 127),
  Color(127, 127, 0),   Color(200, 200, 200), Color(127, 127, 127),
  Color(0, 0, 255),     Color(0, 255, 0),     Color(0, 255, 255),
  Color(255, 0, 0),     Color(255, 0, 255),   Color(255, 255, 0),
  Color(255, 255, 255), Color(128, 128, 128)
}

local color_map_len         = #color_map
local color_clear_sequence  = "\27[0m"

local function sequence_from_color(col)
  local dist, windist, ri

  for i = 1, color_map_len do
    dist = (src.r - color_map[i].r)^2 + (src.g - color_map[i].g)^2 + (src.b - color_map[i].b)^2

    if i == 1 or dist < windist then
      windist = dist
      ri = i
    end
  end

  return available_colors[ri]
end


function print_colored(color, text)
  local color_sequence = color_clear_sequence

  if istable(color) then
    color_sequence = sequence_from_color(color)
  elseif isstring(color) then
    color_sequence = color
  end

  if !isstring(color_sequence) then
    color_sequence = color_clear_sequence
  end

  Msg(color_sequence..text..color_clear_sequence)
end

function MsgC(...)
  local this_sequence = color_clear_sequence

  for k, v in ipairs({...}) do
    if istable(v) then
      this_sequence = sequence_from_color(v)
    else
      print_colored(this_sequence, tostring(v))
    end
  end
end

function ErrorNoHalt(msg)
  Msg('\27[1;37;31m')
  _ErrorNoHalt(msg)
  Msg(color_clear_sequence)
end
