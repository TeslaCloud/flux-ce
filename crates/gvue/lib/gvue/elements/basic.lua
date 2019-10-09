local PANEL = Gvue.basic_element_attributes

local debug_colors = {
  pure_red        = Color(255, 0, 0),
  transparent_red = Color(255, 0, 0, 75),
  pure_white      = Color(255, 255, 255),
  gray            = Color(125, 125, 125)
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
    -- Red fill
    surface.set_draw_color(debug_colors.transparent_red)
    surface.draw_rect(0, 0, w, h)
    
    -- Draw overlaid lines
    surface.set_draw_color(debug_colors.pure_red)

    -- Order as follows: top right bottom left
    surface.draw_line(0, 0, w, 0)
    surface.draw_line(w, 0, w, h)
    surface.draw_line(0, h, w, h)
    surface.draw_line(0, 0, 0, h)

    -- Overlay text and background box
    local panel_info_text = tostring(self.html.element_name)..' '..tostring(w)..'x'..tostring(h)
    local text_wide, text_tall = util.text_size(panel_info_text, 'default')
    draw.rounded_box(4, 1, 1, text_wide + 8, text_tall + 8, debug_colors.pure_white)
    draw.simple_text(panel_info_text, 'default', 5, 5, debug_colors.gray)
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

vgui.Register('gvue_basic_panel', PANEL, 'EditablePanel')
