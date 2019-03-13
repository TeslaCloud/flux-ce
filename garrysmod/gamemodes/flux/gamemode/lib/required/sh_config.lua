-- This library is for serverside configs only!
-- For clientside configs, see cl_settings.lua!

library 'Config'

local stored = Config.stored or {}
Config.stored = stored

local cache = {}

function Config.all()
  return stored
end

function Config.cache()
  return cache
end

if SERVER then
  function Config.load()
    local loaded = Data.load('config', {})

    for k, v in pairs(loaded) do
      Plugin.call('OnConfigSet', key, stored[k] and stored[k].value, value)
      stored[k] = v
    end

    return stored
  end

  function Config.save()
    Data.save('config', stored)
  end

  function Config.set(key, value, hidden, from_config)
    if key != nil then
      if !stored[key] then
        stored[key] = {}

        if PLUGIN then
          stored[key].added_by = PLUGIN:get_name()
        elseif Schema then
          stored[key].added_by = 'Schema'
        else
          stored[key].added_by = 'Flux'
        end

        if isnumber(from_config) then
          if from_config == CONFIG_FLUX then
            stored[key].added_by = 'Flux Config'
          elseif from_config == CONFIG_SCHEMA then
            stored[key].added_by = 'Schema Config'
          elseif PLUGIN and from_config == CONFIG_PLUGIN then
            stored[key].added_by = PLUGIN:get_name()..' Config'
          end
        end
      end

      Plugin.call('OnConfigSet', key, stored[key].value, value)

      stored[key].value = value

      if stored[key].hidden == nil or hidden != nil then
        stored[key].hidden = hidden or false
      end

      if !stored[key].hidden then
        Cable.send(nil, 'fl_config_set_var', key, stored[key].value)
      end

      cache[key] = value
    end
  end

  local player_meta = FindMetaTable('Player')

  function player_meta:send_config()
    for k, v in pairs(stored) do
      if !v.hidden then
        Cable.send(self, 'fl_config_set_var', k, v.value)
      end
    end

    player.fl_has_sent_config = true
  end
else
  local menu_items = Config.menu_items or {}
  Config.menu_items = menu_items

  function Config.set(key, value)
    if key != nil then
      stored[key] = stored[key] or {}

      Plugin.call('OnConfigSet', key, stored[key].value, value)

      stored[key].value = value
      cache[key] = value
    end
  end

  function Config.create_category(id, name, description)
    id = id or 'other'

    if menu_items[id] then return menu_items[id] end

    menu_items[id] = {
      category = { name = name or 'Other', description = description or '' },
      add_key = function(key, name, description, data_type, data)
        Config.add_to_menu(id, key, name, description, data_type, data)
      end,
      add_slider = function(key, name, description, data)
        Config.add_to_menu(id, key, name, description, 'number', data)
      end,
      add_table_editor = function(key, name, description, data)
        Config.add_to_menu(id, key, name, description, 'table', data)
      end,
      add_textbox = function(key, name, description, data)
        Config.add_to_menu(id, key, name, description, 'string', data)
      end,
      add_checkbox = function(key, name, description, data)
        Config.add_to_menu(id, key, name, description, 'bool', data)
      end,
      add_dropdown = function(key, name, description, data)
        Config.add_to_menu(id, key, name, description, 'dropdown', data)
      end,
      configs = {}
    }

    return menu_items[id]
  end

  function Config.get_category(id)
    return menu_items[id]
  end

  function Config.add_to_menu(category, key, name, description, data_type, data)
    if !category or !key then return end

    menu_items[category] = menu_items[category] or {}
    menu_items[category].configs = menu_items[category].configs or {}

    if menu_items[category][key] then return end

    menu_items[category].configs[key] = {
      name = name or key,
      description = description or 'This config has no description set.',
      type = data_type,
      data = data or {}
    }
  end

  function Config.get_menu_keys()
    return menu_items
  end

  Cable.receive('fl_config_set_var', function(key, value)
    if key == nil then return end

    stored[key] = stored[key] or {}
    stored[key].value = value
    cache[key] = value
  end)
end

function Config.get(key, default)
  if cache[key] then
    return cache[key]
  end

  if stored[key] != nil then
    if stored[key].value != nil then
      cache[key] = stored[key].value

      return stored[key].value
    end
  end

  cache[key] = default

  return default
end

if SERVER then
  function Config.import(path, from_config)
    from_config = from_config or CONFIG_FLUX

    local config_table

    if isstring(path) then
      local contents = fileio.Read(path)

      if contents then
        config_table = YAML.eval(contents)
      else
        return
      end
    elseif istable(path) then
      config_table = path
    else
      return
    end

    for k, v in pairs(config_table) do
      if k != 'depends' and Plugin.call('ShouldConfigImport', k, v) == nil then
        Config.set(k, v, nil, from_config)
      end
    end

    return config_table
  end
end

function Config.read(path, from_config)
  from_config = from_config or CONFIG_FLUX

  local config_table

  if isstring(path) then
    config_table = YAML.eval(fileio.Read(path))
  elseif istable(path) then
    config_table = path
  else
    return
  end

  if CLIENT and istable(config_table.categories) then
    for category, data in pairs(config_table.categories) do
      Config.create_category(category, data.name, data.description)
    end
  end

  for name, data in pairs(config_table.configs) do
    if SERVER then
      Config.set(name, data.default_value)
    else
      Config.add_to_menu(data.category or 'general', name, data.name, data.description, data.type, data)
    end
  end
end
