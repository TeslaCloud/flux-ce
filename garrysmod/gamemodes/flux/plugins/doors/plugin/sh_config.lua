Doors:register_property('name', {
  get_save_data = function(entity)
    return entity:get_nv('fl_name', '')
  end,
  on_load = function(entity, data, first)
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
    return entity:get_nv('fl_title_type', DOOR_TITLE_NONE)
  end,
  on_load = function(entity, data, first)
    entity:set_nv('fl_title_type', data)
  end,
  create_panel = function(entity, panel)
    local title_type = panel.properties:CreateRow(t'doors.categories.general', t'doors.properties.title_type.name')
    title_type:Setup('Combo', { text = t'doors.properties.title_type.select' })

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
    local locked = panel.properties:CreateRow(t'doors.categories.general', t'doors.properties.locked')
    locked:Setup('Boolean')

    return locked
  end
})

Doors:register_condition('steamid', {
  name = t'doors.conditions.steamid.name',
  text = t'doors.conditions.steamid.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local steamid = panel_data.steamid
    local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
    local parameter = steamid and steamid..' ('..player.name_from_steamid(steamid)..')' or t'doors.select_parameter'

    return string.format(data.text, operator, parameter)
  end,
  icon = 'vgui/resource/icon_steam',
  check = function(player, entity, data)
    if !data.operator or !data.steamid then return false end

    return util.process_operator(data.operator, player:SteamID(), data.steamid)
  end,
  set_parameters = function(id, data, panel, menu)
    Derma_StringRequest(
      t(data.name),
      t'doors.conditions.steamid.message',
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
  set_operator = 'equal'
})

Doors:register_condition('model', {
  name = t'doors.conditions.model.name',
  text = t'doors.conditions.model.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
    local parameter = panel_data.model or t'doors.select_parameter'

    return string.format(data.text, operator, parameter)
  end,
  icon = 'icon16/bricks.png',
  check = function(player, entity, data)
    if !data.operator or !data.model then return false end

    return util.process_operator(data.operator, player:GetModel(), data.model)
  end,
  set_parameters = function(id, data, panel, menu)
    Derma_StringRequest(
      t(data.name),
      t'doors.conditions.model.message',
      '',
      function(text)
        if text:starts('models') then
          panel.data.model = text

          panel.update()
        else
          data.set_parameters(id, data, panel)
        end
      end
    )
  end,
  set_operator = 'equal'
})

Doors:register_condition('health', {
  name = t'doors.conditions.health.name',
  text = t'doors.conditions.health.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
    local parameter = panel_data.health or t'doors.select_parameter'

    return string.format(data.text, operator, parameter)
  end,
  icon = 'icon16/heart.png',
  check = function(player, entity, data)
    if !data.operator or !data.health then return false end

    return util.process_operator(data.operator, player:Health(), data.health)
  end,
  set_parameters = function(id, data, panel, menu)
    Derma_StringRequest(
      t(data.name),
      t'doors.conditions.health.message',
      '',
      function(text)
        panel.data.health = tonumber(text)

        panel.update()
      end
    )
  end,
  set_operator = 'relational'
})

Doors:register_condition('armor', {
  name = t'doors.conditions.armor.name',
  text = t'doors.conditions.armor.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
    local parameter = panel_data.armor or t'doors.select_parameter'

    return string.format(data.text, operator, parameter)
  end,
  icon = 'icon16/shield.png',
  check = function(player, entity, data)
    if !data.operator or !data.armor then return false end

    return util.process_operator(data.operator, player:Armor(), data.armor)
  end,
  set_parameters = function(id, data, panel, menu)
    Derma_StringRequest(
      t(data.name),
      t'doors.conditions.armor.message',
      '',
      function(text)
        panel.data.armor = tonumber(text)

        panel.update()
      end
    )
  end,
  set_operator = 'relational'
})

Doors:register_condition('active_weapon', {
  name = t'doors.conditions.weapon.name',
  text = t'doors.conditions.weapon.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
    local parameter = panel_data.weapon or t'doors.select_parameter'

    return string.format(data.text, operator, parameter)
  end,
  icon = 'icon16/gun.png',
  check = function(player, entity, data)
    if !data.operator or !data.weapon then return false end
    if !IsValid(player:GetActiveWeapon()) then return false end

    return util.process_operator(data.operator, player:GetActiveWeapon():GetClass(), data.weapon)
  end,
  set_parameters = function(id, data, panel, menu)
    Derma_StringRequest(
      t(data.name),
      t'doors.conditions.weapon.message',
      '',
      function(text)
        panel.data.weapon = text

        panel.update()
      end
    )
  end,
  set_operator = 'equal'
})