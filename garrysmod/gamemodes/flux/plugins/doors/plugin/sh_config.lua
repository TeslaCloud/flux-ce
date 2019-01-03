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

Doors:register_condition('steamid', {
  name = 'Player with specific SteamID',
  text = 'SteamID %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local steamid = panel_data.steamid
    local operator = util.operator_to_symbol(panel_data.operator) or '<Select operator>'
    local parameter = steamid and steamid..' ('..player.name_from_steamid(steamid)..')' or '<Select parameter>'

    return string.format(data.text, operator, parameter)
  end,
  icon = 'icon16/user.png',
  check = function(player, data)
    if !data.operator or !data.steamid then return false end

    return util.process_operator(data.operator, player:SteamID(), data.steamid)
  end,
  set_parameters = function(id, data, panel, menu)
    Derma_StringRequest(
      t(data.name),
      'Input players steamID.',
      '',
      function(text)
        if text:starts('STEAM_') then
          panel.data.steamid = text

          panel.update()
        else
          data.set_parameters(id, data, panel)
        end
      end
    )
  end,
  set_operator = function(id, data, panel, menu)
    Derma_Query(
      'Select operator',
      t(data.name),
      'Equal (==)',
      function()
        panel.data.operator = 'equal'

        panel.update()
      end,
      'Unequal (!=)',
      function()
        panel.data.operator = 'unequal'

        panel.update()
      end
    )
  end
})

Doors:register_condition('character', {
  name = 'Specific character',
  text = 'Character is %s',
  icon = 'icon16/emoticon_smile.png',
  on_check = function(player, value)
    return player:get_active_character_id() == value
  end
})
