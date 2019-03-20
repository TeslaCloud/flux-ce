_MsgC                       = _MsgC         or MsgC
_ErrorNoHalt                = _ErrorNoHalt  or ErrorNoHalt

local available_colors      = {
  "\27[38;5;0m", "\27[38;5;18m", "\27[38;5;22m",
  "\27[38;5;12m", "\27[38;5;52m", "\27[38;5;53m",
  "\27[38;5;3m", "\27[38;5;240m", "\27[38;5;8m",
  "\27[38;5;4m", "\27[38;5;10m", "\27[38;5;14m",
  "\27[38;5;9m", "\27[38;5;13m", "\27[38;5;11m",
  "\27[38;5;15m", "\27[38;5;8m"
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
    dist = (col.r - color_map[i].r)^2 + (col.g - color_map[i].g)^2 + (col.b - color_map[i].b)^2

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
  Msg('\27[41;15m')
  _ErrorNoHalt(msg)
  Msg(color_clear_sequence)
end
