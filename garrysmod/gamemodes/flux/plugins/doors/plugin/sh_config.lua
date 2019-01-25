Doors:register_property('name', {
  get_save_data = function(entity)
    return entity:get_nv('fl_name', '')
  end,
  on_load = function(entity, data)
    entity:set_nv('fl_name', data)
  end,
  create_panel = function(entity, panel)
    local name = panel.properties:CreateRow(t'doors.categories.general', t'doors.properties.name')
    name:Setup('Generic')

    return name
  end
})

Doors:register_property('title_type', {
  get_save_data = function(entity)
    return entity:get_nv('fl_title_type')
  end,
  on_load = function(entity, data)
    entity:set_nv('fl_title_type', data)
  end,
  create_panel = function(entity, panel)
    local title_type = panel.properties:CreateRow(t'doors.categories.general', t'doors.properties.title_type.name')
    title_type:Setup('Combo', { text = t'doors.properties.title_type.select' })

    for k, v in pairs(Doors.title_types) do
      title_type:AddChoice(t(v.name), k)
    end

    title_type:AddChoice(t'doors.title_type.none', '')

    return title_type
  end
})

Doors:register_property('skin', {
  get_save_data = function(entity)
    return entity:GetSkin()
  end,
  on_load = function(entity, data)
    entity:SetSkin(data)
  end
})

Doors:register_property('bodygroups', {
  get_save_data = function(entity)
    return entity:GetBodyGroups()
  end,
  on_load = function(entity, data)
    entity:SetBodyGroups(data)
  end
})

Doors:register_property('locked', {
  get_save_data = function(entity)
    if CLIENT then
      return entity:get_nv('fl_locked')
    else
      return entity:GetInternalVariable('m_bLocked')
    end
  end,
  on_load = function(entity, data)
    data = tobool(data)

    entity:Fire(data and 'Lock' or 'Unlock')

    entity:set_nv('fl_locked', data)
  end,
  create_panel = function(entity, panel)
    local locked = panel.properties:CreateRow(t'doors.categories.general', t'doors.properties.locked')
    locked:Setup('Boolean')

    return locked
  end
})

Doors:register_title_type('center', {
  name = 'doors.title_type.center',
  draw = function(entity, w, h, alpha)
    local text = entity:get_nv('fl_name')
    local font = theme.get_font('text_3d2d')
    local text_w, text_h = util.text_size(text, font)
    local box_x, box_y = -text_w * 0.55, -h / 4 - text_h * 0.55
    local box_w, box_h = text_w * 1.1, text_h * 1.1

    draw.RoundedBox(0, box_x, box_y, box_w, box_h, theme.get_color('background'):alpha(alpha))
    draw.RoundedBox(2, box_x - 4, box_y, box_w + 8, 4, color_white:alpha(alpha))
    draw.RoundedBox(2, box_x- 4, box_y + box_h, box_w + 8, 4, color_white:alpha(alpha))

    draw.SimpleTextOutlined(text, font, -text_w / 2, -h / 4 - text_h / 2, color_white:alpha(alpha), nil, nil, 1, Color(0, 0, 0, alpha))
  end
})
