--- The text panel of Lumen (`lumen_text`), behind the `text` element. It draws its text with
-- the font and the color of its style, wraps it to its width unless `wrap_text` is false,
-- aligns it with `text_align` and `vertical_align`, and measures itself for the layout engine.
-- `set_text` changes the text. Derives from `EditablePanel`.

local text_size        = util.text_size
local draw_simple_text = draw.SimpleText
local math_max         = math.max
local math_floor       = math.floor

local alignments = {
  left = TEXT_ALIGN_LEFT,
  center = TEXT_ALIGN_CENTER,
  right = TEXT_ALIGN_RIGHT
}

local PANEL = {}
PANEL.text = ''
PANEL.lines = nil

--- Sets the text and lays the panel out again if it has changed.
-- @param text [String]
function PANEL:set_text(text)
  text = tostring(text or '')

  if text == self.text then return end

  self.text = text
  self.lines = nil

  self:InvalidateLayout()
  self:InvalidateParent()
end

--- Returns the text.
-- @return [String]
function PANEL:get_text()
  return self.text
end

--- Returns the font of the style, or the default Derma font.
-- @return [String]
function PANEL:get_font()
  local style = self.lumen_style

  return style and style.font or 'DermaDefault'
end

--- Returns the color of the text: the one of the style, or the text color of the theme, or
-- white.
-- @return [Color]
function PANEL:get_text_color()
  local style = self.lumen_style

  if style and style.color then
    return style.color
  end

  return Theme and Theme.get_color('text', color_white) or color_white
end

--- Splits the text into the lines that fit a width.
-- @param width [Number width available to the text, nil to keep the lines as they are]
-- @return [List<String>]
function PANEL:wrap(width)
  local style = Lumen.Layout.style_of(self)
  local font = self:get_font()
  local lines = {}

  for paragraph in (self.text..'\n'):gmatch('([^\n]*)\n') do
    if width and style.wrap_text and paragraph != '' and util.wrap_text then
      local wrapped = util.wrap_text(paragraph, font, math_max(width, 1))

      for k, line in ipairs(wrapped or { paragraph }) do
        lines[#lines + 1] = line
      end
    else
      lines[#lines + 1] = paragraph
    end
  end

  return lines
end

--- Measures lines of text.
-- @param lines [List<String>]
-- @return [Number width of the widest line, Number height of all lines]
function PANEL:measure_lines(lines)
  local font = self:get_font()
  local line_height = util.font_size(font)
  local width = 0

  for k, line in ipairs(lines) do
    local w = text_size(line, font)

    width = math_max(width, w)
  end

  return width, line_height * #lines
end

--- Measures the size the text needs, wrapped to the width available.
-- @param max_w [Number width available, nil if unconstrained]
-- @param max_h [Number height available, nil if unconstrained]
-- @return [Number width, Number height]
function PANEL:lumen_measure(max_w, max_h)
  local pad = Lumen.Layout.style_of(self).padding
  local inner_w = max_w and math_max(max_w - pad.left - pad.right, 0)
  local lines = self:wrap(inner_w)
  local w, h = self:measure_lines(lines)
  local icon_w = self.get_icon_size and self:get_icon_size() or 0

  return w + icon_w + pad.left + pad.right, h + pad.top + pad.bottom
end

--- Wraps the text to the width of the panel.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local pad = Lumen.Layout.style_of(self).padding
  local icon_w = self.get_icon_size and self:get_icon_size() or 0

  self.lines = self:wrap(math_max(w - pad.left - pad.right - icon_w, 1))
end

--- Draws the lines of text with the alignment of the style.
-- @param w [Number panel width]
-- @param h [Number panel height]
-- @param color=nil [Color color to draw with instead of the one of the style]
-- @param offset_x=0 [Number space taken up at the left, by an icon]
function PANEL:draw_text(w, h, color, offset_x)
  local style = Lumen.Layout.style_of(self)
  local pad = style.padding
  local font = self:get_font()
  local lines = self.lines or self:wrap(math_max(w - pad.left - pad.right, 1))
  local line_height = util.font_size(font)
  local total_height = line_height * #lines
  local align = alignments[style.text_align] or TEXT_ALIGN_LEFT
  local inner_left = pad.left + (offset_x or 0)
  local inner_w = w - inner_left - pad.right
  local y = pad.top

  color = color or self:get_text_color()

  if style.vertical_align == 'center' then
    y = pad.top + (h - pad.top - pad.bottom - total_height) * 0.5
  elseif style.vertical_align == 'bottom' then
    y = h - pad.bottom - total_height
  end

  local x = inner_left

  if align == TEXT_ALIGN_CENTER then
    x = inner_left + inner_w * 0.5
  elseif align == TEXT_ALIGN_RIGHT then
    x = inner_left + inner_w
  end

  x = math_floor(x)

  for k, line in ipairs(lines) do
    draw_simple_text(line, font, x, math_floor(y), color, align, TEXT_ALIGN_TOP)

    y = y + line_height
  end
end

--- Draws the background of the style and the text.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Lumen.paint_box(self, w, h)

  self:draw_text(w, h)
end

--- Fires the press handlers of the element.
-- @param code [Number mouse button]
function PANEL:OnMousePressed(code)
  Lumen.press_handler(self, code)
end

vgui.Register('lumen_text', PANEL, 'EditablePanel')
