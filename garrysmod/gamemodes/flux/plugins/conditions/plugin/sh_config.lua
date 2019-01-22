Conditions:register('steamid', {
  name = t'condition.steamid.name',
  text = t'condition.steamid.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local steamid = panel_data.steamid
    local operator = util.operator_to_symbol(panel_data.operator) or t'condition.select_operator'
    local parameter = steamid and steamid..' ('..player.name_from_steamid(steamid)..')' or t'condition.select_parameter'

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
      t'condition.steamid.message',
      '',
      function(text)
        if text:starts('STEAM_') then
          panel.data.steamid = text

          panel.update()
        else
          data.set_parameters(id, data, panel)
        end
      end)
  end,
  set_operator = 'equal'
})

Conditions:register('model', {
  name = t'condition.model.name',
  text = t'condition.model.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'condition.select_operator'
    local parameter = panel_data.model or t'condition.select_parameter'

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
      t'condition.model.message',
      '',
      function(text)
        if text:starts('models') then
          panel.data.model = text

          panel.update()
        else
          data.set_parameters(id, data, panel)
        end
      end)
  end,
  set_operator = 'equal'
})

Conditions:register('health', {
  name = t'condition.health.name',
  text = t'condition.health.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'condition.select_operator'
    local parameter = panel_data.health or t'condition.select_parameter'

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
      t'condition.health.message',
      '',
      function(text)
        panel.data.health = tonumber(text)

        panel.update()
      end)
  end,
  set_operator = 'relational'
})

Conditions:register('armor', {
  name = t'condition.armor.name',
  text = t'condition.armor.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'condition.select_operator'
    local parameter = panel_data.armor or t'condition.select_parameter'

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
      t'condition.armor.message',
      '',
      function(text)
        panel.data.armor = tonumber(text)

        panel.update()
      end)
  end,
  set_operator = 'relational'
})

Conditions:register('active_weapon', {
  name = t'condition.weapon.name',
  text = t'condition.weapon.text'..' %s %s',
  format = function(panel, data)
    local panel_data = panel.data
    local operator = util.operator_to_symbol(panel_data.operator) or t'condition.select_operator'
    local parameter = panel_data.weapon or t'condition.select_parameter'

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
      t'condition.weapon.message',
      '',
      function(text)
        panel.data.weapon = text

        panel.update()
      end)
  end,
  set_operator = 'equal'
})
