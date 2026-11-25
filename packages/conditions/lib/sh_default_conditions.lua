--- Registers the condition types that come with the Conditions package: 'steamid', 'model',
-- 'health', 'armor' and 'active_weapon'.

local operator_to_symbol = util.operator_to_symbol

Conditions:register_condition('steamid', {
  name = 'condition.steamid.name',
  text = 'condition.steamid.text',
  parameter = 'steamid',
  get_value = target -> target:SteamID(),
  --- Builds the arguments for the text of the condition node: the operator symbol
  -- and the SteamID followed by the player's name, or the SteamID alone while the name is not
  -- known.
  -- @param panel [Panel condition node, its parameters are stored in panel.data]
  -- @param _data [Map the registered condition table]
  -- @return [Map operator and steam_id, each an empty string while it is not set]
  get_args = function(panel, _data)
    local steamid = panel.data.steamid
    local operator = operator_to_symbol(panel.data.operator) or ''

    if !isstring(steamid) then
      return { operator = operator, steam_id = '' }
    end

    local name = player.name_from_steamid(steamid) or ''

    return { operator = operator, steam_id = name != '' ? steamid..' ('..name..')' : steamid }
  end,
  icon = 'vgui/resource/icon_steam',
  --- Asks for a SteamID with a text prompt and stores it in the node data in the form the
  -- engine gives it. Prompts again if the input is not a SteamID.
  -- @param id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param _menu=nil [Panel context menu the option was picked from, unused]
  -- @param _parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(id, data, panel, _menu, _parent)
    Derma_StringRequest(
      t(data.name),
      t'condition.steamid.message',
      '',
      function(text)
        local steamid = player.normalize_steam_id(string.Trim(text))

        if player.is_steam_id(steamid) then
          panel.data.steamid = steamid

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
  parameter = 'model',
  get_value = target -> target:GetModel(),
  icon = 'icon16/bricks.png',
  --- Asks for a model path with a text prompt and stores it in the node data.
  -- Prompts again if the input does not start with 'models'.
  -- @param id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param _menu=nil [Panel context menu the option was picked from, unused]
  -- @param _parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(id, data, panel, _menu, _parent)
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
  parameter = 'health',
  get_value = target -> target:Health(),
  icon = 'icon16/heart.png',
  --- Asks for a health value with a text prompt and stores it in the node data as a number.
  -- @param _id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param _menu=nil [Panel context menu the option was picked from, unused]
  -- @param _parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(_id, data, panel, _menu, _parent)
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
  parameter = 'armor',
  get_value = target -> target:Armor(),
  icon = 'icon16/shield.png',
  --- Asks for an armor value with a text prompt and stores it in the node data as a number.
  -- @param _id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param _menu=nil [Panel context menu the option was picked from, unused]
  -- @param _parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(_id, data, panel, _menu, _parent)
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
  parameter = 'weapon',
  --- Gives the class of the player's active weapon.
  -- @param target [Player]
  -- @return [String the weapon class, or nil if the player holds no valid weapon]
  get_value = function(target)
    local weapon = target:GetActiveWeapon()

    if IsValid(weapon) then
      return weapon:GetClass()
    end
  end,
  icon = 'icon16/gun.png',
  --- Asks for a weapon class with a text prompt and stores it in the node data.
  -- @param _id [String condition id]
  -- @param data [Map the registered condition table]
  -- @param panel [Panel condition node that is being edited]
  -- @param _menu=nil [Panel context menu the option was picked from, unused]
  -- @param _parent=nil [Panel the fl_conditions panel, unused]
  set_parameters = function(_id, data, panel, _menu, _parent)
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
