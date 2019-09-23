local PANEL = Gvue.basic_element_attributes

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
