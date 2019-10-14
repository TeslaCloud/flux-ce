local PANEL = {}

local debug_colors = {
  border  = Color(50, 100, 150),
  fill    = Color(50, 100, 150, 60),
  tooltip = Color(255, 255, 255),
  text    = Color(125, 125, 125),
  margin  = Color(200, 150, 50, 90),
  padding = Color(200, 50, 125, 90)
}

function PANEL:Paint(w, h)
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

  return abstract_size * self._gvue.scale
end

function PANEL:set_padding(up, right, down, left)
end

function PANEL:rebuild()
  local w, h = self:ChildrenSize()
  self:SetSize(w, h)
end

vgui.Register('gvue_basic_panel', PANEL, 'EditablePanel')
