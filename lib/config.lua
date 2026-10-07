-- This library is for serverside configs only!
-- For clientside configs, see cl_settings.lua!

mod 'Config'

local stored = Config.stored or {}
Config.stored = stored

local cache = {}

--- Returns the table of all stored configs.
-- @return [Hash config key to config data table (value, hidden, added_by, ...)]
function Config.all()
  return stored
end

--- Returns the value cache that Config.get reads from.
-- @return [Hash config key to cached value]
function Config.cache()
  return cache
end

--- Returns the stored data table of a config rather than just its value.
-- @param id [String config key]
-- @return [Hash config data (value, hidden, added_by, ...), or nil if there is no such config]
function Config.find(id)
  return stored[id]
end

if SERVER then
  --- Loads the saved configs from the 'config' data file and puts them over the stored ones.
  -- Serverside only.
  -- @return [Hash all stored configs]
  function Config.load()
    local loaded = Data.load('config', {})

    for k, v in pairs(loaded) do
      Plugin.call('OnConfigSet', key, stored[k] and stored[k].value, value)
      stored[k] = v
    end

    return stored
  end

  --- Writes all stored configs to the 'config' data file. Serverside only.
  function Config.save()
    Data.save('config', stored)
  end

  --- Sets the value of a config, creating the config if it does not exist yet.
  -- Serverside variant: runs the OnConfigSet hook and sends the new value to all players
  -- unless the config is hidden. Does nothing if key is nil.
  -- @param key [String config key]
  -- @param value [Any new value]
  -- @param hidden=nil [Boolean true to never send this config to clients; nil keeps the
  --   current setting]
  -- @param from_config=nil [Number CONFIG_FLUX, CONFIG_SCHEMA or CONFIG_PLUGIN; only used to
  --   label where a newly created config came from]
  function Config.set(key, value, hidden, from_config)
    if key != nil then
      if !stored[key] then
        stored[key] = {}

        if PLUGIN then
          stored[key].added_by = PLUGIN:get_name()
        elseif SCHEMA then
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

      hook.run('OnConfigSet', key, stored[key].value, value)

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

  --- Sends the values of all non-hidden configs to this player. Serverside only.
  function player_meta:send_config()
    for k, v in pairs(stored) do
      if !v.hidden then
        Cable.send(self, 'fl_config_set_var', k, v.value)
      end
    end

    self.fl_has_sent_config = true
  end
else
  local menu_items = Config.menu_items or {}
  Config.menu_items = menu_items

  --- Sets the value of a config, creating the config if it does not exist yet.
  -- Clientside variant: runs the OnConfigSet hook and changes the local copy only, nothing is
  -- sent to the server. Does nothing if key is nil.
  -- @param key [String config key]
  -- @param value [Any new value]
  function Config.set(key, value)
    if key != nil then
      stored[key] = stored[key] or {}

      Plugin.call('OnConfigSet', key, stored[key].value, value)

      stored[key].value = value
      cache[key] = value
    end
  end

  --- Creates a category for the config menu, or returns the existing one with that ID.
  -- Clientside only. The returned table has the fields category (name and description),
  -- configs, and helper functions that add a config to this category: add_key, add_slider,
  -- add_table_editor, add_textbox, add_checkbox and add_dropdown. The helpers are called
  -- with a dot and take the same arguments as Config.add_to_menu without the category
  -- (and, except for add_key, without the data type).
  -- ```
  -- local category = Config.create_category('general', 'config.general.title',
  --   'config.general.desc')
  --
  -- category.add_slider('walk_speed', 'config.general.walk_speed.name',
  --   'config.general.walk_speed.desc', { min_value = 0, max_value = 1024 })
  -- ```
  -- @param id='other' [String category ID]
  -- @param name='Other' [String display name or language phrase]
  -- @param description='' [String description or language phrase]
  -- @return [Hash category table]
  -- @see [Config.add_to_menu]
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

  --- Returns a config menu category. Clientside only.
  -- @param id [String category ID]
  -- @return [Hash category table, or nil if there is no such category]
  function Config.get_category(id)
    return menu_items[id]
  end

  --- Adds a config to a category of the config menu. Clientside only.
  -- Does nothing if category or key is nil.
  -- @param category [String category ID]
  -- @param key [String config key]
  -- @param name=key [String display name or language phrase]
  -- @param description='This config has no description set.' [String description or language
  --   phrase]
  -- @param data_type=nil [String type of the editor to show, e.g. 'number', 'boolean',
  --   'string' or 'table']
  -- @param data={} [Hash extra data for the editor, e.g. min_value, max_value, decimals,
  --   default_value]
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

  --- Returns all config menu categories together with their configs. Clientside only.
  -- @return [Hash category ID to category table]
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

--- Returns the value of a config.
-- The result is cached, and that includes the default when the config has no value.
-- @param key [String config key]
-- @param default=nil [Any value to return if the config has no value]
-- @return [Any config value, or default]
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
  --- Imports config values from a YAML file or from a table and sets every one of them.
  -- Serverside only. The 'depends' key is skipped, and so is every key for which the
  -- ShouldConfigImport hook returns a non-nil value.
  -- @param path [String/Hash path to a YAML file, or a table of config key to value]
  -- @param from_config=CONFIG_FLUX [Number CONFIG_FLUX, CONFIG_SCHEMA or CONFIG_PLUGIN]
  -- @return [Hash the imported table, or nil if the file could not be read or path is
  --   neither a string nor a table]
  function Config.import(path, from_config)
    from_config = from_config or CONFIG_FLUX

    local config_table

    if isstring(path) then
      local contents = File.read(path)

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

--- Reads config definitions (categories and configs) from a YAML file or from a table.
-- On the server every config is set to its default_value and its definition is stored.
-- On the client the categories and configs are added to the config menu.
-- ```
-- Config.read('gamemodes/flux/config/config.yml')
--
-- Config.read({
--   categories = {
--     general = { name = 'config.general.title', description = 'config.general.desc' }
--   },
--   configs = {
--     walk_speed = {
--       name = 'config.general.walk_speed.name',
--       description = 'config.general.walk_speed.desc',
--       category = 'general',
--       type = 'number',
--       min_value = 0,
--       max_value = 1024,
--       default_value = 100
--     }
--   }
-- })
-- ```
-- @param path [String/Hash path to a YAML file, or the already parsed definitions]
-- @param from_config=CONFIG_FLUX [Number currently unused]
-- @return [Hash the definitions table, or nil if path is neither a string nor a table]
function Config.read(path, from_config)
  from_config = from_config or CONFIG_FLUX

  local config_table

  if isstring(path) then
    config_table = YAML.eval(File.read(path))
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

  if istable(config_table.configs) then
    for name, data in pairs(config_table.configs) do
      if SERVER then
        Config.set(name, data.default_value)
        table.safe_merge(stored[name], data)
      else
        Config.add_to_menu(data.category or 'general', name, data.name, data.description, data.type, data)
      end
    end
  end

  return config_table
end
