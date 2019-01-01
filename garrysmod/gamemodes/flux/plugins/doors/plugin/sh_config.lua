Doors:register_property('name', {
  get_save_data = function(entity)
    return entity:get_nv('fl_name', '')
  end,
  on_load = function(entity, data, first)
    entity:set_nv('fl_name', data)
  end,
  create_panel = function(entity, panel)
    local name = panel.properties:CreateRow('General', 'Name')
    name:Setup('Generic')

    return name
  end
})

Doors:register_property('title_type', {
  get_save_data = function(entity)
    return entity:get_nv('fl_title_type', DOOR_TITLE_NONE)
  end,
  on_load = function(entity, data, first)
    entity:set_nv('fl_title_type', data)
  end,
  create_panel = function(entity, panel)
    local title_type = panel.properties:CreateRow('General', 'Title type')
    title_type:Setup('Combo', { text = 'Select title type...' })

    for k, v in pairs(Doors.title_types) do
      title_type:AddChoice(v.name, v.data)
    end

    return title_type
  end
})

Doors:register_property('skin', {
  get_save_data = function(entity)
    return entity:GetSkin()
  end,
  on_load = function(entity, data, first)
    entity:SetSkin(data)
  end
})

Doors:register_property('bodygroups', {
  get_save_data = function(entity)
    return entity:GetBodyGroups()
  end,
  on_load = function(entity, data, first)
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
  on_load = function(entity, data, first)
    data = tobool(data)

    entity:Fire(data and 'Lock' or 'Unlock')

    entity:set_nv('fl_locked', data)
  end,
  create_panel = function(entity, panel)
    local locked = panel.properties:CreateRow('General', 'Locked')
    locked:Setup('Boolean')

    return locked
  end
})

Doors:register_condition('Player', {
  name = 'Specific player',
  text = 'Player is %s',
  icon = 'icon16/user.png',
  check = function(player, value)
    return player:SteamID() == value
  end
})

Doors:register_condition('Character', {
  name = 'Specific character',
  text = 'Character is %s',
  icon = 'icon16/emoticon_smile.png',
  check = function(player, value)
    return player:get_active_character_id() == value
  end
})
