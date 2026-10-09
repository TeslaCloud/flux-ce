--- Config stores the settings of the server under string keys and shares them with clients.
-- The server owns the values: `Config.set` changes one, runs the OnConfigSet hook and sends
-- the new value to every player who may see it, and `Config.get` reads one on either side.
-- `Config.save` and `Config.load` keep the values in the 'config' data file, and
-- `Config.import` sets them from a YAML file. `Config.read` reads config definitions (default
-- values, names, descriptions and editor types) from YAML, out of which the client builds the
-- categories of the config menu.
--
-- Besides `hidden` (the value is never sent to clients) a definition can carry three flags:
--
-- * `static`: the config cannot be changed in game. Its value comes from the YAML files and
--   from the code only, a value saved in the data file is ignored.
-- * `private`: the value is only sent to the players who may edit configs (see
--   `Config.can_manage`) and `Config.display_value` masks it. The default value is part of
--   the definition and stays public.
-- * `needs_restart`: a change made in game is stored as a pending value and is applied the
--   next time the server starts or changes the map.
--
-- ```
-- configs:
--   server_password:
--     name: config.general.server_password.name
--     description: config.general.server_password.desc
--     category: general
--     type: string
--     private: true
--     needs_restart: true
--     default_value: ""
-- ```
--
-- `Config.set` is the low level setter: it stores whatever it is given and does not look at
-- the flags. Changes requested by players go through `Config.change`, which refuses static
-- configs, checks the value against the definition with `Config.validate` and holds the
-- value back when the config needs a restart, and through `Config.reset`, which puts the
-- default value back.
--
-- These are the settings of the server. The options of an individual player are kept on
-- the client of that player by the Settings plugin (`ClientSettings`).

mod 'Config'

local stored = Config.stored or {}
Config.stored = stored

local definitions = Config.definitions or {}
Config.definitions = definitions

local cache = {}

local boolean_words = {
  ['true'] = true,
  ['yes'] = true,
  ['on'] = true,
  ['1'] = true,
  ['false'] = false,
  ['no'] = false,
  ['off'] = false,
  ['0'] = false
}

Config.permission = Config.permission or 'manage_configuration'

--- Copies a config value, so that changing the copy leaves the original alone.
-- @param value [Any]
-- @return [Any a copy if the value is a table, the value itself otherwise]
local function copy_value(value)
  if istable(value) then
    return table.Copy(value)
  end

  return value
end

--- Checks whether two config values are the same. Tables are compared by their contents.
-- @param first [Any]
-- @param second [Any]
-- @return [Boolean]
local function values_equal(first, second)
  return first == second or (istable(first) and istable(second) and table.equal(first, second))
end

--- Works out the type the value of a config has to have: the type given in its definition,
-- or the type of its current value if it has no definition.
-- @param key [String config key]
-- @return [String 'number', 'boolean', 'string', 'table' or another type named by the
--   definition; nil if the type is not known]
local function expected_type(key)
  local definition = definitions[key]
  local data_type = definition and definition.type

  if data_type == 'bool' then
    return 'boolean'
  elseif isstring(data_type) then
    return data_type
  end

  local current = stored[key] and stored[key].value

  if isnumber(current) then
    return 'number'
  elseif isbool(current) then
    return 'boolean'
  elseif isstring(current) then
    return 'string'
  elseif istable(current) then
    return 'table'
  end
end

--- Returns the table of all stored configs.
-- @return [Map config key to config data table (value, hidden, added_by, ...)]
function Config.all()
  return stored
end

--- Returns the value cache that Config.get reads from.
-- @return [Map config key to cached value]
function Config.cache()
  return cache
end

--- Returns the stored data table of a config rather than just its value.
-- @param id [String config key]
-- @return [Map config data (value, hidden, added_by, ...), or nil if there is no such config]
function Config.find(id)
  return stored[id]
end

--- Returns the definition of a config: the entry that `Config.read` has read for it, with the
-- name, description, category, type, min_value, max_value, default_value and the flags.
-- @param key [String config key]
-- @return [Map config definition, or nil if the config was not defined with Config.read]
function Config.get_definition(key)
  return definitions[key]
end

--- Checks whether a config is static, that is cannot be changed in game.
-- @param key [String config key]
-- @return [Boolean]
function Config.is_static(key)
  local definition = definitions[key]

  return definition != nil and definition.static == true
end

--- Checks whether a config is private. The value of a private config is only sent to the
-- players who may edit configs and is masked by `Config.display_value`.
-- A config that has no definition in this session, for instance because it was loaded from
-- the data file while its plugin is disabled, is judged by the flag that was saved with it.
-- @param key [String config key]
-- @return [Boolean]
function Config.is_private(key)
  local definition = definitions[key] or stored[key]

  return definition != nil and definition.private == true
end

--- Checks whether a change of a config only takes effect after the server has restarted.
-- @param key [String config key]
-- @return [Boolean]
function Config.needs_restart(key)
  local definition = definitions[key]

  return definition != nil and definition.needs_restart == true
end

--- Returns the default value of a config, as given by its definition.
-- @param key [String config key]
-- @return [Any a copy of the default value, or nil if the config has no definition or no
--   default]
function Config.get_default(key)
  local definition = definitions[key]

  if definition then
    return copy_value(definition.default_value)
  end
end

--- Returns the value that a config will take the next time the server starts.
-- Only configs that need a restart get pending values, see `Config.change`. Clients only
-- know the pending values if their player may edit configs.
-- @param key [String config key]
-- @return [Boolean true if a value is pending, Any the pending value]
function Config.get_pending(key)
  local entry = stored[key]

  if entry and entry.pending then
    return true, entry.pending_value
  end

  return false
end

--- Checks whether a player may edit configs, which also lets them see the private ones.
-- The player needs the permission named by `Config.permission`, 'manage_configuration'
-- unless that field has been changed.
-- @param actor [Player player to check; anything else stands for the server console]
-- @return [Boolean on the server true for the console as well, on the client false if the
--   player is not valid]
function Config.can_manage(actor)
  if !IsValid(actor) then
    return SERVER
  end

  return actor:can(Config.permission) and true or false
end

--- Checks a value against the definition of a config and converts it to the type the config
-- expects. Use it on every value that comes from a player before storing it.
-- Numbers may be given as numeric strings, are rounded to the `decimals` of the definition
-- if it has any and are clamped between its `min_value` and `max_value`. Booleans may be
-- given as 1 and 0 or as the strings 'true', 'yes', 'on', '1', 'false', 'no', 'off' and
-- '0'. Strings may be given as numbers. Tables have to be tables. A config without a
-- definition expects the type of its current value, and a config whose type is not one of
-- these takes any string, number, boolean or table.
-- ```
-- local valid, value = Config.validate('walk_speed', '5000')
-- -- true, 1024
--
-- local valid, phrase = Config.validate('walk_speed', 'fast')
-- -- false, 'error.config.not_a_number'
-- ```
-- @param key [String config key]
-- @param value [Any value to check]
-- @return [Boolean whether the value is acceptable, Any the converted value if it is, or the
--   language phrase of the error if it is not]
function Config.validate(key, value)
  local definition = definitions[key] or {}
  local data_type = expected_type(key)

  if data_type == 'number' then
    if isstring(value) then
      value = tonumber(value)
    end

    if !isnumber(value) or value != value or value == math.huge or value == -math.huge then
      return false, 'error.config.not_a_number'
    end

    if isnumber(definition.decimals) then
      value = math.Round(value, definition.decimals)
    end

    if isnumber(definition.min_value) and value < definition.min_value then
      value = definition.min_value
    end

    if isnumber(definition.max_value) and value > definition.max_value then
      value = definition.max_value
    end

    return true, value
  elseif data_type == 'boolean' then
    if isstring(value) then
      value = boolean_words[value:lower()]
    elseif value == 1 or value == 0 then
      value = value == 1
    end

    if !isbool(value) then
      return false, 'error.config.not_a_boolean'
    end

    return true, value
  elseif data_type == 'string' then
    if isnumber(value) then
      value = tostring(value)
    end

    if !isstring(value) then
      return false, 'error.config.not_a_string'
    end

    return true, value
  elseif data_type == 'table' then
    if !istable(value) then
      return false, 'error.config.not_a_table'
    end

    return true, value
  end

  if !isstring(value) and !isnumber(value) and !isbool(value) and !istable(value) then
    return false, 'error.config.invalid_value'
  end

  return true, value
end

--- Converts a config value to a string that can be shown to players, for instance when a
-- change is announced. The value of a private config is replaced with asterisks, and a list
-- is turned into its values separated by commas.
-- @param key [String config key]
-- @param value=Config.get(key) [Any value to show]
-- @return [String]
function Config.display_value(key, value)
  if Config.is_private(key) then
    return '********'
  end

  if value == nil then
    value = Config.get(key)
  end

  if istable(value) and !IsColor(value) and table.IsSequential(value) then
    local pieces = {}

    for k, v in ipairs(value) do
      pieces[#pieces + 1] = tostring(v)
    end

    return table.concat(pieces, ', ')
  end

  return tostring(value)
end

if SERVER then
  --- Lists the players who may edit configs.
  -- @param target=nil [Player only consider this player; every player if nil]
  -- @return [List<Player>]
  local function managers(target)
    local list = {}

    if IsValid(target) then
      if Config.can_manage(target) then
        list[1] = target
      end

      return list
    end

    for k, v in player.Iterator() do
      if Config.can_manage(v) then
        list[#list + 1] = v
      end
    end

    return list
  end

  Cable.check_networked_string('fl_config_set_pending')

  --- Tells the players who may edit configs whether a config has a pending value.
  -- The name of the message is registered when this file loads: Cable delays the first
  -- message under a new name, and a delayed message whose recipient has left in the meantime
  -- would be sent to every player.
  -- @param target [Player only tell this player; every player who may edit configs if nil]
  -- @param key [String config key]
  local function send_pending(target, key)
    local entry = stored[key]

    if !entry or entry.hidden then return end

    local targets = managers(target)

    if #targets > 0 then
      Cable.send(targets, 'fl_config_set_pending', key, entry.pending == true, entry.pending_value)
    end
  end

  --- Gives a value read from the data file the shape of the value it replaces. Colors lose
  -- their metatable when they are saved as JSON, this turns them back into colors.
  -- @param current [Any value the config has before loading]
  -- @param loaded [Any value read from the data file]
  -- @return [Any the loaded value, as a Color if the current value is one]
  local function restore_value(current, loaded)
    if IsColor(current) and istable(loaded) and !IsColor(loaded) then
      if isnumber(loaded.r) and isnumber(loaded.g) and isnumber(loaded.b) then
        return Color(loaded.r, loaded.g, loaded.b, isnumber(loaded.a) and loaded.a or 255)
      end
    end

    return loaded
  end

  --- Loads the saved configs from the 'config' data file and puts them over the stored ones.
  -- Serverside only. This is where the pending value of a config that needs a restart takes
  -- effect. A saved value is skipped if the config is static, if it does not pass
  -- `Config.validate`, or if the config has no definition and was not changed with
  -- `Config.change`, so that a value set in code is not replaced with a stale copy of
  -- itself. A saved config that is not stored at all, such as one of a plugin that is no
  -- longer loaded, is added the way it was saved.
  -- @return [Map all stored configs]
  function Config.load()
    local loaded = Data.load('config', {})

    if !istable(loaded) then
      return stored
    end

    for k, v in pairs(loaded) do
      if !istable(v) then continue end

      local entry = stored[k]
      local value = v.value

      if v.pending then
        value = v.pending_value
      end

      if !entry then
        Plugin.call('OnConfigSet', k, nil, value)

        v.value = value
        v.pending = nil
        v.pending_value = nil

        stored[k] = v
        cache[k] = value
      elseif !Config.is_static(k) and (definitions[k] or v.changed or v.pending) then
        local valid, converted = Config.validate(k, value)

        if valid then
          value = restore_value(entry.value, converted)

          Plugin.call('OnConfigSet', k, entry.value, value)

          entry.value = value
          entry.changed = v.changed
          entry.pending = nil
          entry.pending_value = nil

          cache[k] = value
        end
      end
    end

    return stored
  end

  --- Writes all stored configs to the 'config' data file. Serverside only.
  function Config.save()
    Data.save('config', stored)
  end

  --- Checks whether a player may be sent the value of a config.
  -- Serverside only.
  -- @param actor [Player]
  -- @param key [String config key]
  -- @return [Boolean false if there is no such config, if it is hidden, or if it is private
  --   and the player may not edit configs]
  function Config.can_see(actor, key)
    local entry = stored[key]

    if !entry or entry.hidden then
      return false
    end

    if Config.is_private(key) then
      return Config.can_manage(actor)
    end

    return true
  end

  --- Sends the current value of a config to the players who may see it. Serverside only.
  -- Nothing is sent for a hidden config, and a private one only reaches the players who
  -- may edit configs.
  -- @param target [Player player to send the value to; every player if nil]
  -- @param key [String config key]
  function Config.send(target, key)
    local entry = stored[key]

    if !entry or entry.hidden then return end

    if !Config.is_private(key) then
      Cable.send(target, 'fl_config_set_var', key, entry.value)

      return
    end

    local targets = managers(target)

    if #targets > 0 then
      Cable.send(targets, 'fl_config_set_var', key, entry.value)
    end
  end

  --- Sets the value of a config, creating the config if it does not exist yet.
  -- Serverside variant: runs the OnConfigSet hook and sends the new value to all players
  -- who may see it (see `Config.send`). Does nothing if key is nil. This is the low level
  -- setter: it does not check the value and ignores the static and needs_restart flags.
  -- Use `Config.change` for changes that players ask for.
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

      --- Called when the value of a config is about to change, before the new value is stored.
      -- On the server it runs for every `Config.set`, which includes the defaults set by
      -- `Config.read` and the values set by `Config.import`. On the client it only runs for
      -- values set locally with `Config.set`, not for the ones received from the server,
      -- which run OnConfigReceived instead.
      -- `Config.load` and the client side `Config.set` call it through `Plugin.call`, which
      -- skips gamemode handlers.
      -- @param key [String config key]
      -- @param old_value [Any current value, nil if the config has just been created]
      -- @param new_value [Any value that is about to be stored]
      hook.Run('OnConfigSet', key, stored[key].value, value)

      stored[key].value = value

      if stored[key].hidden == nil or hidden != nil then
        stored[key].hidden = hidden or false
      end

      cache[key] = value

      Config.send(nil, key)
    end
  end

  --- Changes the value of a config the way a player is allowed to. Serverside only.
  -- This is what an editor or a command should call with the value it has received, after
  -- checking that the player may edit configs (see `Config.can_manage`). Unlike `Config.set`
  -- it refuses unknown and static configs, runs the value through `Config.validate` and
  -- honors the needs_restart flag: the value of such a config is not applied but stored as
  -- pending, saved to the data file at once and applied by `Config.load` the next time the
  -- server starts or changes the map.
  -- ```
  -- local success, result, pending = Config.change(key, value)
  --
  -- if !success then
  --   actor:notify(result)
  -- end
  -- ```
  -- @param key [String config key]
  -- @param value [Any new value]
  -- @return [Boolean whether the value was accepted, Any the value as it was stored or the
  --   language phrase of the error, Boolean true if the value is pending and takes effect
  --   after a restart]
  function Config.change(key, value)
    local entry = isstring(key) and stored[key]

    if !entry then
      return false, 'error.config.unknown'
    end

    if Config.is_static(key) then
      return false, 'error.config.static'
    end

    local valid, result = Config.validate(key, value)

    if !valid then
      return false, result
    end

    entry.changed = true

    if Config.needs_restart(key) and !values_equal(entry.value, result) then
      entry.pending = true
      entry.pending_value = result

      send_pending(nil, key)

      Config.save()

      return true, result, true
    end

    local had_pending = entry.pending

    entry.pending = nil
    entry.pending_value = nil

    Config.set(key, result)

    if had_pending then
      send_pending(nil, key)

      Config.save()
    end

    return true, result, false
  end

  --- Puts the default value of a config back. Serverside only.
  -- Follows the same rules as `Config.change`: static configs are refused, and the default
  -- of a config that needs a restart becomes its pending value.
  -- @param key [String config key]
  -- @return [Boolean whether the config was reset, Any the default value or the language
  --   phrase of the error, Boolean true if the default is pending and takes effect after a
  --   restart]
  -- @see [Config.change]
  function Config.reset(key)
    if !isstring(key) or !stored[key] then
      return false, 'error.config.unknown'
    end

    local definition = definitions[key]

    if !definition or definition.default_value == nil then
      return false, 'error.config.no_default'
    end

    return Config.change(key, copy_value(definition.default_value))
  end

  local player_meta = FindMetaTable('Player')

  --- Sends this player the values of all configs they may see: every config that is not
  -- hidden, the private ones only if the player may edit configs, and with those the
  -- pending values. Serverside only.
  -- Can be called again at any time, for instance after the permissions of the player have
  -- changed: a player who may not edit configs (any more) is then told to forget the values
  -- of the private configs and the pending values.
  function player_meta:send_config()
    local resend = self.fl_has_sent_config
    local can_manage

    for k, v in pairs(stored) do
      if !v.hidden then
        local is_private = Config.is_private(k)
        local has_pending = v.pending == true
        local clear_pending = resend and (has_pending or Config.needs_restart(k))

        if can_manage == nil and (is_private or has_pending) then
          can_manage = Config.can_manage(self)
        end

        if !is_private or can_manage then
          Cable.send(self, 'fl_config_set_var', k, v.value)
        elseif resend then
          Cable.send(self, 'fl_config_set_var', k, nil)
        end

        if has_pending and can_manage then
          Cable.send(self, 'fl_config_set_pending', k, true, v.pending_value)
        elseif clear_pending then
          Cable.send(self, 'fl_config_set_pending', k, false, nil)
        end
      end
    end

    self.fl_has_sent_config = true
  end

  Cable.receive('fl_config_request', function(actor)
    if !IsValid(actor) then return end

    local cur_time = CurTime()

    if (actor.fl_next_config_request or 0) > cur_time then return end

    actor.fl_next_config_request = cur_time + 1

    actor:send_config()
  end)
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
  -- @return [Map category table]
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
  -- @return [Map category table, or nil if there is no such category]
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
  -- @param data={} [Map extra data for the editor, e.g. min_value, max_value, decimals,
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
  -- @return [Map category ID to category table]
  function Config.get_menu_keys()
    return menu_items
  end

  --- Asks the server to send the config values again. Clientside only.
  -- Private configs and pending values only reach the players who may edit configs, and
  -- the server decides that at the moment it sends them. A config editor should call this
  -- when it opens to get the values its player is allowed to see by then; they arrive
  -- shortly after and run the OnConfigReceived and OnConfigPendingReceived hooks. The server
  -- answers one request per second.
  function Config.request()
    Cable.send('fl_config_request')
  end

  Cable.receive('fl_config_set_var', function(key, value)
    if key == nil then return end

    stored[key] = stored[key] or {}

    local old_value = stored[key].value

    stored[key].value = value
    cache[key] = value

    --- Called on the client when the value of a config has arrived from the server and has
    -- been stored: when the player joins, whenever the config is changed on the server and
    -- after `Config.request`. The value of a private config only arrives if the player may
    -- edit configs, and nil arrives for it once they no longer may.
    -- @param key [String config key]
    -- @param old_value [Any value the client had before]
    -- @param new_value [Any value that has been received]
    hook.Run('OnConfigReceived', key, old_value, value)
  end)

  Cable.receive('fl_config_set_pending', function(key, is_pending, value)
    if key == nil then return end

    stored[key] = stored[key] or {}

    if is_pending then
      stored[key].pending = true
      stored[key].pending_value = value
    else
      stored[key].pending = nil
      stored[key].pending_value = nil
    end

    --- Called on the client when the server reports that a config has got a pending value,
    -- or that it no longer has one. Pending values belong to the configs that need a
    -- restart and are only sent to the players who may edit configs.
    -- @param key [String config key]
    -- @param is_pending [Boolean whether the config has a pending value now]
    -- @param value [Any value the config takes on the next start of the server, nil if
    --   nothing is pending]
    -- @see [Config.get_pending]
    hook.Run('OnConfigPendingReceived', key, is_pending and true or false, value)
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
  -- Serverside only. The 'depends' and 'depends_development' keys are skipped, and so is
  -- every key for which the ShouldConfigImport hook returns a non-nil value.
  -- @param path [String/Map path to a YAML file, or a table of config key to value]
  -- @param from_config=CONFIG_FLUX [Number CONFIG_FLUX, CONFIG_SCHEMA or CONFIG_PLUGIN]
  -- @return [Map the imported table, or nil if the file could not be read or path is
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
      --- Called on the server for every key that `Config.import` is about to set.
      -- @param key [String config key]
      -- @param value [Any value read from the imported file or table]
      -- @return [Boolean Return any value other than nil to skip the key and keep its current
      --   value]
      if k != 'depends' and k != 'depends_development' and Plugin.call('ShouldConfigImport', k, v) == nil then
        Config.set(k, v, nil, from_config)
      end
    end

    return config_table
  end
end

--- Reads config definitions (categories and configs) from a YAML file or from a table.
-- On the server every config is set to its default_value and its definition is stored.
-- On the client the categories and configs are added to the config menu. Both sides keep
-- the definitions for `Config.get_definition`. Besides the fields shown below a config can
-- be marked with `hidden`, `static`, `private` and `needs_restart`, which are described at
-- the top of this file.
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
-- @param path [String/Map path to a YAML file, or the already parsed definitions]
-- @param from_config=CONFIG_FLUX [Number currently unused]
-- @return [Map the definitions table, or nil if path is neither a string nor a table]
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
      definitions[name] = data

      if SERVER then
        Config.set(name, copy_value(data.default_value))
        table.safe_merge(stored[name], data)
      else
        Config.add_to_menu(data.category or 'general', name, data.name, data.description, data.type, data)
      end
    end
  end

  return config_table
end
