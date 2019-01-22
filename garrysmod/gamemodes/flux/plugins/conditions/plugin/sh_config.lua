Conditions:register_condition('steamid', {
  name = 'conditions.steamid.name',
  text = 'conditions.steamid.text',
  get_args = function(panel, data)
    local steamid = panel.data.steamid
    local operator = util.operator_to_symbol(panel.data.operator)
    local parameter = steamid and steamid..' ('..player.name_from_steamid(steamid)..')'

    return { operator, parameter }
  end,
  icon = 'vgui/resource/icon_steam',
  check = function(player, data)
    if !data.operator or !data.steamid then return false end

    return util.process_operator(data.operator, player:SteamID(), data.steamid)
  end,
  set_parameters = function(id, data, panel, menu, parent)
    Derma_StringRequest(
      t(data.name),
      t'conditions.steamid.message',
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

Conditions:register_condition('model', {
  name = 'conditions.model.name',
  text = 'conditions.model.text',
  get_args = function(panel, data)
    local operator = util.operator_to_symbol(panel.data.operator)
    local parameter = panel.data.model

    return { operator, parameter }
  end,
  icon = 'icon16/bricks.png',
  check = function(player, data)
    if !data.operator or !data.model then return false end

    return util.process_operator(data.operator, player:GetModel(), data.model)
  end,
  set_parameters = function(id, data, panel, menu, parent)
    Derma_StringRequest(
      t(data.name),
      t'conditions.model.message',
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

Conditions:register_condition('health', {
  name = 'conditions.health.name',
  text = 'conditions.health.text',
  get_args = function(panel, data)
    local operator = util.operator_to_symbol(panel.data.operator)
    local parameter = panel.data.health

    return { operator, parameter }
  end,
  icon = 'icon16/heart.png',
  check = function(player, data)
    if !data.operator or !data.health then return false end

    return util.process_operator(data.operator, player:Health(), data.health)
  end,
  set_parameters = function(id, data, panel, menu, parent)
    Derma_StringRequest(
      t(data.name),
      t'conditions.health.message',
      '',
      function(text)
        panel.data.health = tonumber(text)

        panel.update()
      end)
  end,
  set_operator = 'relational'
})

Conditions:register_condition('armor', {
  name = 'conditions.armor.name',
  text = 'conditions.armor.text',
  get_args = function(panel, data)
    local operator = util.operator_to_symbol(panel.data.operator)
    local parameter = panel.data.armor

    return { operator, parameter }
  end,
  icon = 'icon16/shield.png',
  check = function(player, data)
    if !data.operator or !data.armor then return false end

    return util.process_operator(data.operator, player:Armor(), data.armor)
  end,
  set_parameters = function(id, data, panel, menu, parent)
    Derma_StringRequest(
      t(data.name),
      t'conditions.armor.message',
      '',
      function(text)
        panel.data.armor = tonumber(text)

        panel.update()
      end)
  end,
  set_operator = 'relational'
})

Conditions:register_condition('active_weapon', {
  name = 'conditions.weapon.name',
  text = 'conditions.weapon.text',
  get_args = function(panel, data)
    local operator = util.operator_to_symbol(panel.data.operator)
    local parameter = panel.data.weapon

    return { operator, parameter }
  end,
  icon = 'icon16/gun.png',
  check = function(player, data)
    if !data.operator or !data.weapon then return false end
    if !IsValid(player:GetActiveWeapon()) then return false end

    return util.process_operator(data.operator, player:GetActiveWeapon():GetClass(), data.weapon)
  end,
  set_parameters = function(id, data, panel, menu, parent)
    Derma_StringRequest(
      t(data.name),
      t'conditions.weapon.message',
      '',
      function(text)
        panel.data.weapon = text

        panel.update()
      end)
  end,
  set_operator = 'equal'
})
