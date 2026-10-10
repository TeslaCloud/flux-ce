--- Registers the condition types that come with the Conditions plugin: 'steamid', 'model',
-- 'health', 'armor' and 'active_weapon'.

local process_operator = util.process_operator
local operator_to_symbol = util.operator_to_symbol

Conditions:register_condition('steamid', {
  name = 'condition.steamid.name',
  text = 'condition.steamid.text',
  --- Builds the arguments for the text of the condition node: the operator symbol
  -- and the SteamID followed by the player's name.
  -- @param panel [Panel condition node, its parameters are stored in panel.data]
  -- @param data [Map the registered condition table]
  -- @return [Map operator and steam_id, each an empty string while it is not set]
  get_args = function(panel, data)
    local steamid = panel.data.steamid
    local operator = operator_to_symbol(panel.data.operator) or ''
    local parameter = steamid and steamid..' ('..player.name_from_steamid(steamid)..')' or ''

    return { operator = operator, steam_id = parameter }
  end,
  icon = 'vgui/resource/icon_steam',
  --- Compares the player's SteamID with the stored value using the chosen operator.
  -- @param target [Player]
  -- @param data [Map condition parameters: operator, steamid]
  -- @return [Boolean result of the comparison, false if the operator or the value is not set]
  check = function(target, data)
    if !data.operator or !data.steamid then return false end

    return process_operator(data.operator, target:SteamID(), data.steamid)
  end,
  --- Asks for a SteamID with a text prompt and stores it in the node data.
  -- Prompts again if the input does not start with 'STEAM_'.
  -- @param id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param menu=nil [Panel context menu the option was picked from, unused]
  -- @param parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(id, data, panel, menu, parent)
    Derma_StringRequest(
      t(data.name),
      t'condition.steamid.message',
      '',
      function(text)
        if text:start_with('STEAM_') then
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
  name = 'condition.model.name',
  text = 'condition.model.text',
  --- Builds the arguments for the text of the condition node: the operator symbol
  -- and the model path.
  -- @param panel [Panel condition node, its parameters are stored in panel.data]
  -- @param data [Map the registered condition table]
  -- @return [Map operator and model, each an empty string while it is not set]
  get_args = function(panel, data)
    local operator = operator_to_symbol(panel.data.operator) or ''
    local parameter = panel.data.model or ''

    return { operator = operator, model = parameter }
  end,
  icon = 'icon16/bricks.png',
  --- Compares the player's model with the stored value using the chosen operator.
  -- @param target [Player]
  -- @param data [Map condition parameters: operator, model]
  -- @return [Boolean result of the comparison, false if the operator or the value is not set]
  check = function(target, data)
    if !data.operator or !data.model then return false end

    return process_operator(data.operator, target:GetModel(), data.model)
  end,
  --- Asks for a model path with a text prompt and stores it in the node data.
  -- Prompts again if the input does not start with 'models'.
  -- @param id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param menu=nil [Panel context menu the option was picked from, unused]
  -- @param parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(id, data, panel, menu, parent)
    Derma_StringRequest(
      t(data.name),
      t'condition.model.message',
      '',
      function(text)
        if text:start_with('models') then
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
  name = 'condition.health.name',
  text = 'condition.health.text',
  --- Builds the arguments for the text of the condition node: the operator symbol
  -- and the health value.
  -- @param panel [Panel condition node, its parameters are stored in panel.data]
  -- @param data [Map the registered condition table]
  -- @return [Map operator and health, each an empty string while it is not set]
  get_args = function(panel, data)
    local operator = operator_to_symbol(panel.data.operator) or ''
    local parameter = panel.data.health or ''

    return { operator = operator, health = parameter }
  end,
  icon = 'icon16/heart.png',
  --- Compares the player's health with the stored value using the chosen operator.
  -- @param target [Player]
  -- @param data [Map condition parameters: operator, health]
  -- @return [Boolean result of the comparison, false if the operator or the value is not set]
  check = function(target, data)
    if !data.operator or !data.health then return false end

    return process_operator(data.operator, target:Health(), data.health)
  end,
  --- Asks for a health value with a text prompt and stores it in the node data as a number.
  -- @param id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param menu=nil [Panel context menu the option was picked from, unused]
  -- @param parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(id, data, panel, menu, parent)
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

Conditions:register_condition('armor', {
  name = 'condition.armor.name',
  text = 'condition.armor.text',
  --- Builds the arguments for the text of the condition node: the operator symbol
  -- and the armor value.
  -- @param panel [Panel condition node, its parameters are stored in panel.data]
  -- @param data [Map the registered condition table]
  -- @return [Map operator and armor, each an empty string while it is not set]
  get_args = function(panel, data)
    local operator = operator_to_symbol(panel.data.operator) or ''
    local parameter = panel.data.armor or ''

    return { operator = operator, armor = parameter }
  end,
  icon = 'icon16/shield.png',
  --- Compares the player's armor with the stored value using the chosen operator.
  -- @param target [Player]
  -- @param data [Map condition parameters: operator, armor]
  -- @return [Boolean result of the comparison, false if the operator or the value is not set]
  check = function(target, data)
    if !data.operator or !data.armor then return false end

    return process_operator(data.operator, target:Armor(), data.armor)
  end,
  --- Asks for an armor value with a text prompt and stores it in the node data as a number.
  -- @param id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param menu=nil [Panel context menu the option was picked from, unused]
  -- @param parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(id, data, panel, menu, parent)
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

Conditions:register_condition('active_weapon', {
  name = 'condition.weapon.name',
  text = 'condition.weapon.text',
  --- Builds the arguments for the text of the condition node: the operator symbol
  -- and the weapon class.
  -- @param panel [Panel condition node, its parameters are stored in panel.data]
  -- @param data [Map the registered condition table]
  -- @return [Map operator and weapon, each an empty string while it is not set]
  get_args = function(panel, data)
    local operator = operator_to_symbol(panel.data.operator) or ''
    local parameter = panel.data.weapon or ''

    return { operator = operator, weapon = parameter }
  end,
  icon = 'icon16/gun.png',
  --- Compares the class of the player's active weapon with the stored value
  -- using the chosen operator.
  -- @param target [Player]
  -- @param data [Map condition parameters: operator, weapon]
  -- @return [Boolean result of the comparison, false if the operator or the value is not
  --   set or the player has no valid active weapon]
  check = function(target, data)
    if !data.operator or !data.weapon then return false end

    local weapon = target:GetActiveWeapon()

    if !IsValid(weapon) then return false end

    return process_operator(data.operator, weapon:GetClass(), data.weapon)
  end,
  --- Asks for a weapon class with a text prompt and stores it in the node data.
  -- @param id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param menu=nil [Panel context menu the option was picked from, unused]
  -- @param parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(id, data, panel, menu, parent)
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
