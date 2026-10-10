--- The layout engine of Lumen: a flexbox without shrinking. A
-- container (`view`, `scroll`) lays its children out along its `direction`: each child takes
-- the size its style asks for or the size of its content, children with `flex` share the space
-- that is left, `justify` distributes any remaining space, `align` places the children across
-- the direction and `wrap` starts new lines when they do not fit. The sizes come from the
-- resolved styles (`Lumen.Style`) that the reconciler stores on the panels as `lumen_style`;
-- a panel that defines `lumen_measure(max_w, max_h)` reports the size of its content, any
-- other panel is taken at its current size.
-- @module [Lumen.Layout]

mod 'Lumen::Layout'

local IsValid    = IsValid
local math_floor = math.floor
local math_max   = math.max
local length     = Lumen.Style.length
local clamp      = Lumen.Style.clamp

local empty_style = Lumen.Style.resolve(nil)

--- Returns the resolved style of a panel.
-- @param panel [Panel]
-- @return [Map resolved style, an empty one for panels without]
function Lumen.Layout.style_of(panel)
  return panel.lumen_style or empty_style
end

--- Measures a panel: the size its style asks for, with the content filling in the dimensions
-- that are auto, kept within the minimum and maximum of the style.
-- @param panel [Panel]
-- @param max_w [Number width available to the panel, nil if unconstrained]
-- @param max_h [Number height available to the panel, nil if unconstrained]
-- @return [Number width, Number height]
function Lumen.Layout.measure(panel, max_w, max_h)
  local style = Lumen.Layout.style_of(panel)
  local w = length(style.width, max_w)
  local h = length(style.height, max_h)

  if !w or !h then
    local content_w, content_h

    if panel.lumen_measure then
      content_w, content_h = panel:lumen_measure(w or max_w, h or max_h)
    else
      content_w, content_h = panel:GetSize()
    end

    w = w or content_w or 0
    h = h or content_h or 0
  end

  w = clamp(w, style.min_width, style.max_width, max_w)
  h = clamp(h, style.min_height, style.max_height, max_h)

  return w, h
end

--- Lists the children of a container that take part in the layout: the valid, visible panels
-- of its `lumen_children` list, or of all of its children when the list is missing.
-- @param container [Panel]
-- @param children=nil [List<Panel> the children to filter, `container.lumen_children` or
--   `container:GetChildren()` if nil]
-- @return [List<Panel>]
function Lumen.Layout.children_of(container, children)
  children = children or container.lumen_children or container:GetChildren()

  local visible = {}

  for k, child in ipairs(children) do
    if IsValid(child) and child:IsVisible() then
      visible[#visible + 1] = child
    end
  end

  return visible
end

--- Lays out children as a flex container would, or only measures the size they need.
-- ```
-- -- In the PerformLayout of a container:
-- Lumen.Layout.flex(self.lumen_style, Lumen.Layout.children_of(self), w, h, true)
--
-- -- To measure the content of a container:
-- local content_w, content_h = Lumen.Layout.flex(self.lumen_style, children, max_w, max_h, false)
-- ```
-- @param style [Map resolved style of the container]
-- @param children [List<Panel> children to lay out]
-- @param avail_w [Number width of the container, nil if it is unconstrained]
-- @param avail_h [Number height of the container, nil if it is unconstrained]
-- @param apply [Boolean position and size the children; false only measures]
-- @return [Number width the content needs, padding included, Number height likewise]
function Lumen.Layout.flex(style, children, avail_w, avail_h, apply)
  local pad = style.padding
  local row = style.direction == 'row'
  local gap = style.gap or 0
  local inner_w = avail_w and math_max(avail_w - pad.left - pad.right, 0)
  local inner_h = avail_h and math_max(avail_h - pad.top - pad.bottom, 0)
  local main_avail = row and inner_w or inner_h
  local cross_avail = row and inner_h or inner_w
  local items = {}

  for k, child in ipairs(children) do
    local child_style = Lumen.Layout.style_of(child)
    local margin = child_style.margin
    local max_w = inner_w and math_max(inner_w - margin.left - margin.right, 0)
    local max_h = inner_h and math_max(inner_h - margin.top - margin.bottom, 0)
    local w, h = Lumen.Layout.measure(child, max_w, max_h)
    local flex = child_style.flex or 0
    local main_margin = row and (margin.left + margin.right) or (margin.top + margin.bottom)
    local cross_margin = row and (margin.top + margin.bottom) or (margin.left + margin.right)
    local measured_main = row and w or h
    local fixed_main = (row and child_style.width != nil) or (!row and child_style.height != nil)
    local base = measured_main

    if flex > 0 and main_avail and !fixed_main then
      base = 0
    end

    items[#items + 1] = {
      panel = child,
      style = child_style,
      w = w,
      h = h,
      base = base,
      flex = flex,
      main_margin = main_margin,
      cross_margin = cross_margin,
      cross = row and h or w,
      fixed_cross = (row and child_style.height or child_style.width) != nil,
      align = child_style.align_self or style.align
    }
  end

  local lines = {}
  local line = {}
  local line_used = 0

  for k, item in ipairs(items) do
    local size = item.base + item.main_margin
    local needed = line_used + (#line > 0 and gap or 0) + size

    if style.wrap and main_avail and #line > 0 and needed > main_avail then
      lines[#lines + 1] = line
      line = {}
      line_used = size
    else
      line_used = needed
    end

    line[#line + 1] = item
  end

  if #line > 0 or #lines == 0 then
    lines[#lines + 1] = line
  end

  local content_main = 0
  local cross_pos = 0

  for line_index, current in ipairs(lines) do
    local count = #current
    local used = gap * math_max(count - 1, 0)
    local total_flex = 0
    local line_cross = 0

    for k, item in ipairs(current) do
      used = used + item.base + item.main_margin
      total_flex = total_flex + item.flex
    end

    local free = math_max((main_avail or used) - used, 0)

    for k, item in ipairs(current) do
      item.main = item.base

      if total_flex > 0 and item.flex > 0 then
        item.main = item.base + free * item.flex / total_flex
      end

      line_cross = math_max(line_cross, item.cross + item.cross_margin)
    end

    if total_flex > 0 then
      free = 0
    end

    if apply and cross_avail and #lines == 1 then
      line_cross = cross_avail
    end

    local offset = 0
    local between = gap
    local justify = style.justify

    if free > 0 and count > 0 then
      if justify == 'center' then
        offset = free * 0.5
      elseif justify == 'end' then
        offset = free
      elseif justify == 'space_between' and count > 1 then
        between = gap + free / (count - 1)
      elseif justify == 'space_around' then
        offset = free / count * 0.5
        between = gap + free / count
      elseif justify == 'space_evenly' then
        offset = free / (count + 1)
        between = gap + free / (count + 1)
      end
    end

    local main_pos = offset

    for k, item in ipairs(current) do
      local margin = item.style.margin
      local cross_size = item.cross
      local align = item.align

      if align == 'stretch' and !item.fixed_cross then
        cross_size = math_max(line_cross - item.cross_margin, 0)
      end

      local cross_offset

      if align == 'center' then
        cross_offset = (line_cross - cross_size - item.cross_margin) * 0.5
      elseif align == 'end' then
        cross_offset = line_cross - cross_size - item.cross_margin
      else
        cross_offset = 0
      end

      if apply then
        local main_size = item.main
        local x, y, w, h

        if row then
          x = pad.left + main_pos + margin.left
          y = pad.top + cross_pos + cross_offset + margin.top
          w = clamp(main_size, item.style.min_width, item.style.max_width, inner_w)
          h = clamp(cross_size, item.style.min_height, item.style.max_height, inner_h)
        else
          x = pad.left + cross_pos + cross_offset + margin.left
          y = pad.top + main_pos + margin.top
          w = clamp(cross_size, item.style.min_width, item.style.max_width, inner_w)
          h = clamp(main_size, item.style.min_height, item.style.max_height, inner_h)
        end

        item.panel:SetPos(math_floor(x + 0.5), math_floor(y + 0.5))
        item.panel:SetSize(math_floor(w + 0.5), math_floor(h + 0.5))
      end

      main_pos = main_pos + item.main + item.main_margin + between
    end

    if count > 0 then
      content_main = math_max(content_main, main_pos - between)
    end

    cross_pos = cross_pos + line_cross + gap
  end

  local content_cross = math_max(cross_pos - gap, 0)

  if row then
    return content_main + pad.left + pad.right, content_cross + pad.top + pad.bottom
  end

  return content_cross + pad.left + pad.right, content_main + pad.top + pad.bottom
end
