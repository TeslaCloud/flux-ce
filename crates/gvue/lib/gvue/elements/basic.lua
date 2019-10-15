local PANEL = Gvue.new_panel()

local debug_colors = {
  border  = Color(50, 100, 150),
  fill    = Color(50, 100, 150, 60),
  tooltip = Color(255, 255, 255),
  text    = Color(125, 125, 125),
  margin  = Color(200, 150, 50, 90),
  padding = Color(200, 50, 125, 90)
}

local function create_acccessor_trbl(id)
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
    surface.set_draw_color(debug_colors.fill)
    surface.draw_rect(
      attrs.padding_left,
      attrs.padding_top,
      w - attrs.padding_right - attrs.padding_left - 1,
      h - attrs.padding_top - attrs.padding_bottom - 1
    )

    -- Draw margin boundaries
    surface.set_draw_color(debug_colors.margin)

    draw.stenciled(function()
      surface.draw_rect(
        -attrs.margin_left,
        -attrs.margin_top,
        w + attrs.margin_left + attrs.margin_right,
        h + attrs.margin_top + attrs.margin_bottom
      )
    end, function()
      surface.draw_rect(0, 0, w, h)
    end)

    -- Draw padding boundaries
    surface.set_draw_color(debug_colors.padding)

    draw.stenciled(function()
      surface.draw_rect(0, 0, w, h)
    end, function()
      surface.draw_rect(
        attrs.padding_left,
        attrs.padding_top,
        w - attrs.padding_right - attrs.padding_left - 1,
        h - attrs.padding_top - attrs.padding_bottom - 1
      )
    end)

    -- Draw overlaid lines
    surface.set_draw_color(debug_colors.border)

    -- Order as follows: top right bottom left
    surface.draw_line(0, 0, w, 0)
    surface.draw_line(w - 1, 0, w - 1, h)
    surface.draw_line(0, h - 1, w, h - 1)
    surface.draw_line(0, 0, 0, h)

    -- Overlay text and background box
    local panel_info_text = tostring(self.html.element_name)..' '..tostring(w)..'x'..tostring(h)
    local text_wide, text_tall = util.text_size(panel_info_text, 'default')
    draw.rounded_box(4, 1, -text_tall - 9, text_wide + 8, text_tall + 8, debug_colors.tooltip)
    draw.simple_text(panel_info_text, 'default', 5, -text_tall - 5, debug_colors.text)

    surface.DisableClipping(false)
  end
end

function PANEL:unit_to_px(num, units, what, use_abstract_pixels)
  if !isnumber(num) then return 0 end

  local abstract_size = Gvue:get_unit_callback(units)(self, num, what)

  if use_abstract_pixels then
    return abstract_size
  end

  return abstract_size * self.scale
end

function PANEL:set_size(w, h)
  self.context.width = w
  self.context.height = h
  self:SetSize(w, h)
end

function PANEL:size()
  return self.context.width, self.context.height
end

function PANEL:set_pos(x, y)
  self.context.x = x
  self.context.y = y
  self:SetPos(x, y)
end

function PANEL:pos()
  return self.context.x, self.context.y
end

function PANEL:rebuild()
  local w, h = self:ChildrenSize()
  self:SetSize(w, h)
end

create_acccessor_trbl()
create_acccessor_trbl 'padding'
create_acccessor_trbl 'margin'

vgui.Register('gvue_basic_panel', PANEL, 'EditablePanel')
