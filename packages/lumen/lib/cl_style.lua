--- Styles of Lumen elements. The `style` prop of an element is a table, and this library
-- resolves it into the form the panels and the layout engine read:
-- lengths are scaled to the screen resolution with `math.scale` (set `scale = false` in the
-- style to keep them as they are), shorthands are expanded, and colors and fonts may name
-- values of the active theme.
-- ```
-- <view style={{ direction = 'row', gap = 8, padding = { 4, 12 }, background = 'main_dark' }}>
--   <text style={{ flex = 1, font = 'text_normal', color = 'text' }}>Name</text>
--   <text style={{ width = '25%', text_align = 'right', color = '#ff8800' }}>42</text>
-- </view>
-- ```
-- The properties are:
--
-- * Size: `width`, `height`, `min_width`, `min_height`, `max_width`, `max_height`. A number is
--   a length, a string such as '50%' is a share of the parent's inner size, 'auto' (or nothing)
--   lets the content decide.
-- * Flex item: `flex` (Number how much of the free space of the parent the element takes, 0 by
--   default), `margin` (a length for all sides, `{ vertical, horizontal }`,
--   `{ top, right, bottom, left }` or `{ top = n, left = n, ... }`) along with `margin_top`,
--   `margin_right`, `margin_bottom` and `margin_left`, and `align_self` ('start', 'center',
--   'end' or 'stretch', which overrides the parent's `align` for this element).
-- * Flex container (`view`, `scroll`): `direction` ('column' by default or 'row'), `justify`
--   ('start', 'center', 'end', 'space_between', 'space_around' or 'space_evenly'), `align`
--   ('stretch' by default, 'start', 'center' or 'end'), `gap` (length between the children),
--   `wrap` (Boolean start a new line when the children do not fit) and `padding` (like
--   `margin`, with `padding_top` and the others).
-- * Looks: `background` (Color), `border` (Color), `border_width` (1 by default), `radius`
--   (rounded corners), `alpha` (0 to 255, the whole panel), `cursor` (such as 'hand').
-- * Text (`text`, `button`): `font`, `font_size` (derives a copy of the font at that size),
--   `color`, `text_align` ('left', 'center' or 'right'), `vertical_align` ('top', 'center' or
--   'bottom'), `wrap_text` (Boolean wrap long lines, true by default).
-- * Button: `hover_background`, `active_background`, `disabled_color`.
-- * Position: `x` and `y` place an element that is mounted into a panel that is not a Lumen
--   container at that spot (the layout engine positions everything else).
--
-- A color may be a Color, the name of a color of the active theme (`Theme.get_color`) or a
-- hex string ('#rgb', '#rrggbb' or '#rrggbbaa'). A font may be the name of a font of the
-- active theme (`Theme.get_font`) or the name of a font created with `surface.CreateFont`.
-- @module [Lumen.Style]

mod 'Lumen::Style'

local isstring   = isstring
local isnumber   = isnumber
local istable    = istable
local tonumber   = tonumber
local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

local sides = { 'top', 'right', 'bottom', 'left' }

--- Scales a length to the screen resolution.
-- @param value [Number length at 1080p]
-- @param scaled [Boolean false leaves the length as it is]
-- @return [Number]
local function scale(value, scaled)
  if scaled == false then return value end

  return math.scale(value)
end

--- Resolves a size: a length, a percentage or auto.
-- @param value [Number/String the size as written]
-- @param scaled [Boolean whether lengths are scaled]
-- @return [Number/Map the length, `{ percent = n }`, or nil for auto]
local function resolve_size(value, scaled)
  if isnumber(value) then
    return scale(value, scaled)
  elseif isstring(value) then
    local percent = tonumber(value:match('^%s*(-?[%d%.]+)%%%s*$'))

    if percent then
      return { percent = percent }
    end

    return tonumber(value) and scale(tonumber(value), scaled) or nil
  end

  return nil
end

--- Resolves a box of four lengths: margins or paddings.
-- @param style [Map the style as written]
-- @param name [String 'margin' or 'padding']
-- @param scaled [Boolean whether lengths are scaled]
-- @return [Map top, right, bottom and left lengths]
local function resolve_box(style, name, scaled)
  local value = style[name]
  local box = { top = 0, right = 0, bottom = 0, left = 0 }

  if isnumber(value) then
    local length = scale(value, scaled)

    box.top, box.right, box.bottom, box.left = length, length, length, length
  elseif istable(value) then
    if #value == 2 then
      local vertical, horizontal = scale(value[1], scaled), scale(value[2], scaled)

      box.top, box.bottom = vertical, vertical
      box.right, box.left = horizontal, horizontal
    elseif #value == 4 then
      box.top = scale(value[1], scaled)
      box.right = scale(value[2], scaled)
      box.bottom = scale(value[3], scaled)
      box.left = scale(value[4], scaled)
    else
      for k, side in ipairs(sides) do
        if isnumber(value[side]) then
          box[side] = scale(value[side], scaled)
        end
      end
    end
  end

  for k, side in ipairs(sides) do
    local override = style[name..'_'..side]

    if isnumber(override) then
      box[side] = scale(override, scaled)
    end
  end

  return box
end

--- Parses a hex color string.
-- @param text [String '#rgb', '#rrggbb' or '#rrggbbaa']
-- @return [Color, or nil if the string is not a hex color]
local function parse_hex_color(text)
  local hex = text:match('^#(%x+)$')

  if !hex then return end

  if #hex == 3 then
    hex = hex:gsub('.', '%0%0')
  end

  if #hex != 6 and #hex != 8 then return end

  local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
  local a = #hex == 8 and tonumber(hex:sub(7, 8), 16) or 255

  return Color(r, g, b, a)
end

--- Resolves a color: a Color, the name of a theme color or a hex string.
-- @param value [Any]
-- @return [Color, or nil if there is no such color]
function Lumen.Style.color(value)
  if IsColor(value) then
    return value
  elseif isstring(value) then
    local hex = parse_hex_color(value)

    if hex then return hex end

    if Theme and Theme.get_color then
      local themed = Theme.get_color(value)

      if IsColor(themed) then return themed end
    end
  end

  return nil
end

--- Resolves a font: the name of a theme font or the name of a created font, at a size.
-- @param value [String]
-- @param size=nil [Number size to derive a copy of the font at, already scaled]
-- @return [String name of the font, or nil if none was given]
function Lumen.Style.font(value, size)
  if !isstring(value) then return nil end

  local font = value

  if Theme and Theme.get_font then
    local themed = Theme.get_font(value)

    if isstring(themed) then
      font = themed
    end
  end

  if size and Font and Font.size then
    font = Font.size(font, math_floor(size)) or font
  end

  return font
end

local plain_keys = {
  'flex', 'direction', 'justify', 'align', 'align_self', 'wrap', 'text_align', 'vertical_align',
  'wrap_text', 'cursor', 'alpha', 'x', 'y'
}

local color_keys = {
  'background', 'border', 'color', 'hover_background', 'active_background', 'disabled_color'
}

local size_keys = {
  'width', 'height', 'min_width', 'min_height', 'max_width', 'max_height'
}

--- Resolves a style table into the form the panels and the layout engine read: scaled lengths,
-- expanded boxes, Colors and font names. Defaults fill in what the style does not set.
-- @param style [Map the style as written, or nil]
-- @param defaults=nil [Map the default style of the element, in the same form as `style`]
-- @return [Map the resolved style]
function Lumen.Style.resolve(style, defaults)
  local merged = {}

  if istable(defaults) then
    for k, v in pairs(defaults) do
      merged[k] = v
    end
  end

  if istable(style) then
    for k, v in pairs(style) do
      merged[k] = v
    end
  end

  local scaled = merged.scale != false
  local resolved = { scaled = scaled }

  for k, key in ipairs(plain_keys) do
    resolved[key] = merged[key]
  end

  for k, key in ipairs(size_keys) do
    resolved[key] = resolve_size(merged[key], scaled)
  end

  for k, key in ipairs(color_keys) do
    resolved[key] = Lumen.Style.color(merged[key])
  end

  resolved.margin = resolve_box(merged, 'margin', scaled)
  resolved.padding = resolve_box(merged, 'padding', scaled)
  resolved.gap = isnumber(merged.gap) and scale(merged.gap, scaled) or 0
  resolved.radius = isnumber(merged.radius) and scale(merged.radius, scaled) or 0
  resolved.border_width = isnumber(merged.border_width) and scale(merged.border_width, scaled) or scale(1, scaled)
  resolved.font_size = isnumber(merged.font_size) and scale(merged.font_size, scaled) or nil
  resolved.font = Lumen.Style.font(merged.font, resolved.font_size)
  resolved.direction = merged.direction == 'row' and 'row' or 'column'
  resolved.justify = merged.justify or 'start'
  resolved.align = merged.align or 'stretch'
  resolved.wrap = merged.wrap == true
  resolved.wrap_text = merged.wrap_text != false
  resolved.flex = isnumber(merged.flex) and math_max(merged.flex, 0) or 0

  return resolved
end

--- Turns a resolved size into pixels.
-- @param size [Number/Map a resolved size: a length or `{ percent = n }`]
-- @param available [Number the size of the parent that percentages refer to, nil if unknown]
-- @return [Number pixels, or nil if the size is auto or a percentage of an unknown size]
function Lumen.Style.length(size, available)
  if isnumber(size) then
    return size
  elseif istable(size) and available then
    return available * size.percent / 100
  end

  return nil
end

--- Keeps a length between the minimum and the maximum of a resolved style.
-- @param value [Number]
-- @param min [Number/Map resolved minimum, or nil]
-- @param max [Number/Map resolved maximum, or nil]
-- @param available [Number size that percentages refer to, nil if unknown]
-- @return [Number]
function Lumen.Style.clamp(value, min, max, available)
  local min_length = Lumen.Style.length(min, available)
  local max_length = Lumen.Style.length(max, available)

  if max_length then
    value = math_min(value, max_length)
  end

  if min_length then
    value = math_max(value, min_length)
  end

  return value
end
