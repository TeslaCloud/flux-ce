local PANEL = {
  _gvue = {
    html = {
      attributes = {},
      element_name = 'gvue_basic_panel',
      inner_html = ''
    },
    context = {
      attributes = {
        padding = { up = 0, right = 0, down = 0, left = 0 },
        margin  = { up = 0, right = 0, down = 0, left = 0 },
        up = 0, down = 0, left = 0, right = 0,
        background = { color = nil, image = nil },
        border = { radius = 0, size = 0, color = color_white },
        color = color_white,
        font = 'default',
        font_size = 16,
        display = 'block',
        position = 'relative',
        width = nil, max_width = nil, min_width = nil,
        height = nil, max_height = nil, min_height = nil
      },
      inner = nil,
      parent = nil,
      width = 0,
      height = 0
    },
    scale = 1
  }
}

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
