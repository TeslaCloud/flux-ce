local PANEL = Gvue.new_panel()

local debug_colors = {
  border  = Color(50, 100, 150),
  fill    = Color(50, 100, 150, 60),
  tooltip = Color(255, 255, 255),
  text    = Color(125, 125, 125),
  margin  = Color(200, 150, 50, 90),
  padding = Color(200, 50, 125, 90)
}

local function create_accessor_trbl(id)
  local t, r, b, l = '_top', '_right', '_bottom', '_left'

  if !id or id == '' then
    id = ''
    t, r, b, l = 'top', 'right', 'bottom', 'left'
  else
    PANEL['set_'..id] = function(obj, top, right, bottom, left, real_val)
      real_val = real_val or string.fmt(
        '{top}px {right}px {bottom}px {left}px',
        {
          top = top, right = right, bottom = bottom, left = left
        })
      obj.context.attributes[id..t] = top
      obj.context.attributes[id..r] = right
      obj.context.attributes[id..b] = bottom
      obj.context.attributes[id..l] = left
      obj.context.attributes[id]    = real_val
    end

    PANEL[id] = function(obj)
      local ctx = obj.context.attributes
      return ctx[id..t],
            ctx[id..r],
            ctx[id..b],
            ctx[id..l]
    end
  end

  for _, keyword in ipairs({ t, r, b, l }) do
    local kwd = id..keyword
    PANEL[kwd] = function(obj)
      return obj.context.attributes[kwd]
    end

    if id == '' then
      PANEL['set_'..kwd] = function(obj, val)
        obj.context.attributes[keyword] = val
      end
    end
  end
end

--- Runs the element's pre_tick, tick and post_tick callbacks once per tick_delay
-- seconds, and its quick_tick callback every frame.
function PANEL:Think()
  local w, h = self:GetSize()
  local cur_time = CurTime()

  if self.next_think < cur_time then
    if isfunction(self.pre_tick) then
      self:pre_tick(w, h, cur_time)
    end

    if isfunction(self.tick) then
      self:tick(w, h, cur_time)
    end

    if isfunction(self.post_tick) then
      self:tock(w, h, cur_time)
    end

    self.next_think = cur_time + self.tick_delay
  end

  if isfunction(self.quick_tick) then
    self:quick_tick(w, h, cur_time)
  end
end

--- Draws the element by calling its draw_background, draw_border, draw, draw_foreground
-- and draw_overlay methods in this order, followed by the debug overlay if it is enabled.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  self.hovered = self:IsHovered()

  if isfunction(self.draw_background) then
    self:draw_background(w, h)
  end

  if isfunction(self.draw_border) then
    self:draw_border(w, h)
  end

  if isfunction(self.draw) then
    self:draw(w, h)
  end

  if isfunction(self.draw_foreground) then
    self:draw_foreground(w, h)
  end

  if isfunction(self.draw_overlay) then
    self:draw_overlay(w, h)
  end

  if self.draw_debug_overlay then
    local attrs = self.context.attributes
    surface.DisableClipping(true)

    -- Background fill
    surface.SetDrawColor(debug_colors.fill)
    surface.DrawRect(
      attrs.padding_left,
      attrs.padding_top,
      w - attrs.padding_right - attrs.padding_left - 1,
      h - attrs.padding_top - attrs.padding_bottom - 1
    )

    -- Draw margin boundaries
    surface.SetDrawColor(debug_colors.margin)

    draw.stenciled(function()
      surface.DrawRect(
        -attrs.margin_left,
        -attrs.margin_top,
        w + attrs.margin_left + attrs.margin_right,
        h + attrs.margin_top + attrs.margin_bottom
      )
    end, function()
      surface.DrawRect(0, 0, w, h)
    end)

    -- Draw padding boundaries
    surface.SetDrawColor(debug_colors.padding)

    draw.stenciled(function()
      surface.DrawRect(0, 0, w, h)
    end, function()
      surface.DrawRect(
        attrs.padding_left,
        attrs.padding_top,
        w - attrs.padding_right - attrs.padding_left - 1,
        h - attrs.padding_top - attrs.padding_bottom - 1
      )
    end)

    -- Draw overlaid lines
    surface.SetDrawColor(debug_colors.border)

    -- Order as follows: top right bottom left
    surface.DrawLine(0, 0, w, 0)
    surface.DrawLine(w - 1, 0, w - 1, h)
    surface.DrawLine(0, h - 1, w, h - 1)
    surface.DrawLine(0, 0, 0, h)

    -- Overlay text and background box
    local panel_info_text = tostring(self.html.element_name)..' '..tostring(w)..'x'..tostring(h)
    local text_wide, text_tall = util.text_size(panel_info_text, 'default')
    draw.RoundedBox(4, 1, -text_tall - 9, text_wide + 8, text_tall + 8, debug_colors.tooltip)
    draw.SimpleText(panel_info_text, 'default', 5, -text_tall - 5, debug_colors.text)

    surface.DisableClipping(false)
  end
end

--- Converts a number in CSS units to pixels, in the context of this element.
-- @param num [Number value to convert]
-- @param units [String CSS unit, e.g. 'px', 'em' or '%']
-- @param what=nil [String attribute the value belongs to, used by relative units]
-- @param use_abstract_pixels=false [Boolean do not multiply the result by the element's
--   scale]
-- @return [Number size in pixels; 0 if num is not a number]
function PANEL:unit_to_px(num, units, what, use_abstract_pixels)
  if !isnumber(num) then return 0 end

  local abstract_size = Gvue:get_unit_callback(units)(self, num, what)

  if use_abstract_pixels then
    return abstract_size
  end

  return abstract_size * self.scale
end

--- Sets the size of the element and stores it in its layout context.
-- @param w [Number width in pixels]
-- @param h [Number height in pixels]
function PANEL:set_size(w, h)
  self.context.width = w
  self.context.height = h
  self:SetSize(w, h)
end

--- Returns the size stored in the element's layout context.
-- @return [Number width, Number height]
function PANEL:size()
  return self.context.width, self.context.height
end

--- Sets the position of the element and stores it in its layout context.
-- @param x [Number]
-- @param y [Number]
function PANEL:set_pos(x, y)
  self.context.x = x
  self.context.y = y
  self:SetPos(x, y)
end

--- Returns the position stored in the element's layout context.
-- @return [Number x, Number y]
function PANEL:pos()
  return self.context.x, self.context.y
end

--- Resizes the element to fit its children.
function PANEL:rebuild()
  local w, h = self:ChildrenSize()
  self:SetSize(w, h)
end

create_accessor_trbl()
create_accessor_trbl 'padding'
create_accessor_trbl 'margin'

vgui.Register('gvue_basic_panel', PANEL, 'EditablePanel')
