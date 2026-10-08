--- Registers the door properties that come with the Doors plugin ('name', 'title_type',
-- 'skin', 'bodygroups' and 'locked') and the 'center' title type.

Doors:register_property('name', {
  --- Returns the name of the door.
  -- @param entity [Entity the door]
  -- @return [String the name, or an empty string if the door has no name]
  get_save_data = function(entity)
    return entity:get_nv('fl_name', '')
  end,
  --- Sets the networked name of the door.
  -- @param entity [Entity the door]
  -- @param data [String the name]
  on_load = function(entity, data)
    entity:set_nv('fl_name', data)
  end,
  --- Creates the text row for the name of the door in the door menu.
  -- @param entity [Entity the door]
  -- @param panel [Panel the fl_door_menu panel]
  -- @return [Panel the created property row]
  create_panel = function(entity, panel)
    local name = panel.properties:CreateRow(t'door.categories.general', t'door.properties.name')
    name:Setup('Generic')

    return name
  end
})

Doors:register_property('title_type', {
  --- Returns the id of the title type of the door.
  -- @param entity [Entity the door]
  -- @return [String the title type id, or nil if it has never been set]
  get_save_data = function(entity)
    return entity:get_nv('fl_title_type')
  end,
  --- Sets the networked title type of the door.
  -- @param entity [Entity the door]
  -- @param data [String title type id, an empty string to disable the title]
  on_load = function(entity, data)
    entity:set_nv('fl_title_type', data)
  end,
  --- Creates the combo box row with all registered title types in the door menu.
  -- @param entity [Entity the door]
  -- @param panel [Panel the fl_door_menu panel]
  -- @return [Panel the created property row]
  create_panel = function(entity, panel)
    local title_type = panel.properties:CreateRow(t'door.categories.general', t'door.properties.title_type.name')
    title_type:Setup('Combo', { text = t'door.properties.title_type.select' })

    for k, v in pairs(Doors.title_types) do
      title_type:AddChoice(t(v.name), k)
    end

    title_type:AddChoice(t'door.title_type.none', '')

    return title_type
  end
})

Doors:register_property('skin', {
  --- Returns the skin of the door.
  -- @param entity [Entity the door]
  -- @return [Number the skin index]
  get_save_data = function(entity)
    return entity:GetSkin()
  end,
  --- Sets the skin of the door.
  -- @param entity [Entity the door]
  -- @param data [Number the skin index]
  on_load = function(entity, data)
    entity:SetSkin(data)
  end
})

Doors:register_property('bodygroups', {
  --- Returns the bodygroups of the door.
  -- @param entity [Entity the door]
  -- @return [List bodygroup tables as returned by Entity:GetBodyGroups]
  get_save_data = function(entity)
    return entity:GetBodyGroups()
  end,
  --- Passes the saved bodygroups to Entity:SetBodyGroups.
  -- @param entity [Entity the door]
  -- @param data [List the bodygroups that were saved by get_save_data]
  on_load = function(entity, data)
    entity:SetBodyGroups(data)
  end
})

Doors:register_property('locked', {
  --- Returns whether the door is locked. Reads the networked value on the client
  -- and the internal state of the door on the server.
  -- @param entity [Entity the door]
  -- @return [Boolean]
  get_save_data = function(entity)
    if CLIENT then
      return entity:get_nv('fl_locked')
    else
      return entity:GetInternalVariable('m_bLocked')
    end
  end,
  --- Locks or unlocks the door and networks its new state. Serverside only.
  -- @param entity [Entity the door]
  -- @param data [Boolean true to lock the door; other values are converted with tobool]
  on_load = function(entity, data)
    data = tobool(data)

    entity:Fire(data and 'Lock' or 'Unlock')

    entity:set_nv('fl_locked', data)
  end,
  --- Creates the checkbox row for the lock state of the door in the door menu.
  -- @param entity [Entity the door]
  -- @param panel [Panel the fl_door_menu panel]
  -- @return [Panel the created property row]
  create_panel = function(entity, panel)
    local locked = panel.properties:CreateRow(t'door.categories.general', t'door.properties.locked')
    locked:Setup('Boolean')

    return locked
  end
})

Doors:register_title_type('center', {
  name = 'door.title_type.center',
  --- Draws the name of the door on a background box with white bars above and below it,
  -- a quarter of the door's height away from the center of the door.
  -- @param entity [Entity the door]
  -- @param w [Number width of the door face in drawing units]
  -- @param h [Number height of the door face in drawing units]
  -- @param alpha [Number opacity that fades with distance, up to 255]
  draw = function(entity, w, h, alpha)
    local text = entity:get_nv('fl_name')
    local font = Theme.get_font('text_3d2d')
    local text_w, text_h = util.text_size(text, font)
    local box_x, box_y = -text_w * 0.55, -h / 4 - text_h * 0.55
    local box_w, box_h = text_w * 1.1, text_h * 1.1

    draw.RoundedBox(0, box_x, box_y, box_w, box_h, Theme.get_color('background'):alpha(alpha))
    draw.RoundedBox(2, box_x - 4, box_y, box_w + 8, 4, color_white:alpha(alpha))
    draw.RoundedBox(2, box_x - 4, box_y + box_h, box_w + 8, 4, color_white:alpha(alpha))

    draw.SimpleTextOutlined(
      text,
      font,
      -text_w / 2,
      -h / 4 - text_h / 2,
      color_white:alpha(alpha),
      nil,
      nil,
      1,
      Color(0, 0, 0, alpha)
    )
  end
})
