function Gvue.new_panel()
  return {
    html = {
      attributes = {},
      element_name = 'gvue_basic_panel',
      inner_html = ''
    },
    context = {
      attributes = {
        padding = '0',
        padding_top = 0, padding_right = 0, padding_bottom = 0, padding_left = 0,
        margin = '0',
        margin_top = 0, margin_right = 0, margin_bottom = 0, margin_left = 0,
        up = 0, down = 0, left = 0, right = 0,
        background = '0',
        background_color = nil, background_image = nil,
        border = '0',
        border_radius = 0, border_size = 0, border_color = color_white,
        color = color_white,
        font_family = 'default',
        font_size = 16,
        display = 'block',
        position = 'relative',
        width = nil, max_width = nil, min_width = nil,
        height = nil, max_height = nil, min_height = nil,
        text_align = 'left',
        flex = nil,
        flex_grow = 0, flex_shrink = 0, flex_basis = 0,
        flex_wrap = 'nowrap', flex_direction = 'row',
        justify_content = 'flex-start', align_items = 'stretch',
        align_self = 'auto', align_content = 'stretch',
        line_height = 0, column_width = 0,
        order = 0
      },
      inner = nil,
      parent = nil,
      width = 0,
      height = 0
    },
    scale = 1,
    draw_debug_overlay = false
  }
end
