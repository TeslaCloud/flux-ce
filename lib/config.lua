--- Config stores the settings of the server under string keys and shares them with clients.
-- The server owns the values: `Config.set` changes one, runs the ConfigChanged hook and sends
-- the new value to every player who may see it, and `Config.get` reads one on either side.
-- `Config.save` and `Config.load` keep the values changed in game in the 'config' data file,
-- and `Config.import` sets them from a YAML file. `Config.read` reads config definitions
-- (default values, names, descriptions and editor types) from YAML, out of which the client
-- builds the categories of the config menu.
--
-- A config takes the first of these that applies, after a boot and after a code refresh alike:
-- the value changed in game (`Config.change`), kept over refreshes and restarts; the value of
-- the `server.configuration` section of `settings.yml`; the value of the schema's .yml file;
-- the `default_value` of its definition. A config that was never changed in game, or that has
-- been reset with `Config.reset`, follows its files and its definition whenever the server
-- starts.
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
--   flow_walk_speed:
--     name: config.flow.walk_speed.name
--     description: config.flow.walk_speed.desc
--     category: flow
--     type: number
--     min_value: 0
--     max_value: 1024
--     default_value: 100
-- ```
--
-- `Config.set` is the low level setter: it stores whatever it is given and does not look at
-- the flags. Changes requested by players go through `Config.change`, which refuses static
-- configs, checks the value against the definition with `Config.validate` and holds the
-- value back when the config needs a restart, and through `Config.reset`, which puts back the
-- value the files give.
--
-- `Config.set` and `Config.import` label where a config came from with one of the sources
-- defined here: `CONFIG_PLUGIN` (a plugin's config file), `CONFIG_SCHEMA` (the schema's config
-- file) or `CONFIG_FLUX` (the server configuration of Flux).
--
-- These are the settings of the server. The options of an individual player are kept on
-- the client of that player by the Client Settings package (`ClientSettings`).

local pairs = pairs
local istable = istable
local isstring = isstring
local isnumber = isnumber
local isbool = isbool
local IsValid = IsValid
local tostring = tostring

mod 'Config'

enumerate 'CONFIG_PLUGIN CONFIG_SCHEMA CONFIG_FLUX'

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

local function copy_value(value)
  if istable(value) then
    return table.Copy(value)
  end

  return value
end

--- Reads one channel of a color: a finite number, rounded and clamped between 0 and 255.
-- @param value [Any]
-- @return [Number the channel, or nil if the value is not a finite number]
local function color_channel(value)
  if !isnumber(value) or value != value or value == math.huge or value == -math.huge then return end

  return math.Clamp(math.Round(value), 0, 255)
end

--- Returns a copy of the default value of a definition, as a Color for a config of the color
-- type, whose default is written as a table with the r, g and b fields.
-- @param definition [Map config definition]
-- @return [Any]
local function default_value(definition)
  if definition.type == 'color' then
    return util.to_color(copy_value(definition.default_value))
  end

  return copy_value(definition.default_value)
end

--- Tells whether two config values are equal: the same value, or two tables with the same
-- contents, as two colors or lists with equal entries are.
-- @param first [Any]
-- @param second [Any]
-- @return [Boolean]
function Config.values_equal(first, second)
  return first == second or (istable(first) and istable(second) and table.equal(first, second))
end

local values_equal = Config.values_equal

--- Tells whether `Config.read` puts the default value of a definition into a config: when the
-- config has no value yet, or when it was never changed in game and still holds the default of
-- the definition it had before and no file has set it.
-- @param entry [Map stored config data, nil if there is none]
-- @param previous [Map definition the config had before, nil if it had none]
-- @return [Boolean]
local function takes_default(entry, previous)
  if !entry or entry.value == nil then return true end
  if entry.changed or entry.imported_from != nil or !previous then return false end

  return values_equal(entry.value, default_value(previous))
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
    return default_value(definition)
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

  return actor:can(Config.permission) ? true : false
end

--- Checks a value against the definition of a config and converts it to the type the config
-- expects. Use it on every value that comes from a player before storing it.
-- Numbers may be given as numeric strings, are rounded to the `decimals` of the definition
-- if it has any and are clamped between its `min_value` and `max_value`. Booleans may be
-- given as 1 and 0 or as the strings 'true', 'yes', 'on', '1', 'false', 'no', 'off' and
-- '0'. Strings may be given as numbers. Tables have to be tables. Colors may be given as
-- any table with finite numbers in the r, g, b and, optionally, a fields, which are rounded
-- and clamped between 0 and 255, or as a string that `util.string_to_color` reads; they are
-- turned into a Color with an alpha of 255 unless one is given. A
-- config without a definition expects the type of its current value, and a config whose type
-- is not one of these takes any string, number, boolean or table.
-- ```
-- local valid, value = Config.validate('flow_walk_speed', '5000')
-- -- true, 1024
--
-- local valid, phrase = Config.validate('flow_walk_speed', 'fast')
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
  elseif data_type == 'color' then
    if isstring(value) then
      value = util.string_to_color(value)
    end

    if !istable(value) then
      return false, 'error.config.not_a_color'
    end

    local r, g, b = color_channel(value.r), color_channel(value.g), color_channel(value.b)
    local a = value.a == nil ? 255 : color_channel(value.a)

    if !r or !g or !b or !a then
      return false, 'error.config.not_a_color'
    end

    return true, Color(r, g, b, a)
  end

  if !isstring(value) and !isnumber(value) and !isbool(value) and !istable(value) then
    return false, 'error.config.invalid_value'
  end

  return true, value
end

--- Converts a config value to a string that can be shown to players, for instance when a
-- change is announced. The value of a private config is replaced with asterisks, a color is
-- turned into its red, green, blue and alpha channels and a list into its values, separated by
-- commas.
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

  if expected_type(key) == 'color' then
    local color = util.to_color(value)

    if color then
      local round = math.Round

      return string.format('%d, %d, %d, %d', round(color.r), round(color.g), round(color.b), round(color.a))
    end
  end

  if istable(value) and !IsColor(value) and table.IsSequential(value) then
    local pieces = {}

    for _, element in ipairs(value) do
      pieces[#pieces + 1] = tostring(element)
    end

    return table.concat(pieces, ', ')
  end

  return tostring(value)
end

if SERVER then
  local function managers(target)
    local list = {}

    if IsValid(target) then
      if Config.can_manage(target) then
        list[1] = target
      end

      return list
    end

    for _, client in player.Iterator() do
      if Config.can_manage(client) then
        list[#list + 1] = client
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

  --- Loads the configs changed in game from the 'config' data file and puts them over the
  -- stored ones. Serverside only. This is where the pending value of a config that needs a
  -- restart takes effect. A saved value is skipped if it was neither changed with
  -- `Config.change` nor is pending, if the config is static, or if it does not pass
  -- `Config.validate`, so that the files and the definition decide every other value. A saved
  -- config that is not stored at all, such as one of a plugin that is not loaded, is added the
  -- way it was saved and is saved again.
  -- @return [Map all stored configs]
  function Config.load()
    local loaded = Data.load('config', {})

    if !istable(loaded) then
      return stored
    end

    for key, saved in pairs(loaded) do
      if !istable(saved) or !(saved.changed or saved.pending) then continue end

      local entry = stored[key]
      local value = saved.value

      if saved.pending then
        value = saved.pending_value
      end

      if !entry then
        saved.value = value
        saved.pending = nil
        saved.pending_value = nil

        stored[key] = saved
        cache[key] = value

        Plugin.call('ConfigChanged', key, nil, value)
      elseif !Config.is_static(key) then
        local valid, converted = Config.validate(key, value)

        if valid then
          local old_value = entry.value

          value = restore_value(old_value, converted)

          entry.value = value
          entry.changed = saved.changed
          entry.pending = nil
          entry.pending_value = nil

          cache[key] = value

          Plugin.call('ConfigChanged', key, old_value, value)
        end
      end
    end

    return stored
  end

  --- Writes the configs that have been changed in game or have a pending value to the 'config'
  -- data file. Serverside only.
  function Config.save()
    local changed = {}

    for key, entry in pairs(stored) do
      if entry.changed or entry.pending then
        changed[key] = entry
      end
    end

    Data.save('config', changed)
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
  -- Serverside variant: runs the ConfigChanged hook and sends the new value to all players
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
      local entry = stored[key]

      if !entry then
        entry = {}
        stored[key] = entry

        if PLUGIN then
          entry.added_by = PLUGIN:get_name()
        elseif SCHEMA then
          entry.added_by = 'Schema'
        else
          entry.added_by = 'Flux'
        end

        if isnumber(from_config) then
          if from_config == CONFIG_FLUX then
            entry.added_by = 'Flux Config'
          elseif from_config == CONFIG_SCHEMA then
            entry.added_by = 'Schema Config'
          elseif PLUGIN and from_config == CONFIG_PLUGIN then
            entry.added_by = PLUGIN:get_name()..' Config'
          end
        end
      end

      local old_value = entry.value

      entry.value = value

      if entry.hidden == nil or hidden != nil then
        entry.hidden = hidden or false
      end

      cache[key] = value

      Config.send(nil, key)

      --- Called when the value of a config has been set, once the new value is stored, so
      -- `Config.get(key)` returns it. On the server it runs for every `Config.set`, which
      -- includes the defaults set by `Config.read` and the values set by `Config.import`,
      -- and for every value `Config.load` restores. On the client it only runs for values
      -- set locally with `Config.set`, not for the ones received from the server, which run
      -- ConfigReceived instead. `Config.load` and the client side `Config.set` call it
      -- through `Plugin.call`, which skips gamemode handlers. The return value is ignored.
      -- @param key [String config key]
      -- @param old_value [Any previous value, nil if the config has just been created]
      -- @param new_value [Any value that has been stored]
      hook.Run('ConfigChanged', key, old_value, value)
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

  --- Puts a config back into the state of one that was never changed in game. Serverside only.
  -- The config takes the value its files give it, the one `Config.import` last set from
  -- `settings.yml` or the schema's .yml file, else the default of its definition, and loses its
  -- changed mark, so the next `Config.save` leaves it out and it follows its files and its
  -- definition from then on. Static configs are refused. For a config that needs a restart that
  -- value becomes pending and takes effect the next time the server starts; otherwise it is set
  -- at once, which tells the players and runs ConfigChanged like a change does.
  -- @param key [String config key]
  -- @return [Boolean whether the config was reset, Any the value it takes or the language
  --   phrase of the error, Boolean true if the value is pending and takes effect after a
  --   restart]
  -- @see [Config.change]
  function Config.reset(key)
    local entry = isstring(key) and stored[key]

    if !entry then
      return false, 'error.config.unknown'
    end

    if Config.is_static(key) then
      return false, 'error.config.static'
    end

    local definition = definitions[key]
    local value

    if entry.imported_from != nil then
      value = copy_value(entry.imported_value)
    elseif definition and definition.default_value != nil then
      value = default_value(definition)
    else
      return false, 'error.config.no_default'
    end

    local had_pending = entry.pending

    entry.changed = nil

    if Config.needs_restart(key) and !values_equal(entry.value, value) then
      entry.pending = true
      entry.pending_value = value

      send_pending(nil, key)

      Config.save()

      return true, value, true
    end

    entry.pending = nil
    entry.pending_value = nil

    Config.set(key, value)

    if had_pending then
      send_pending(nil, key)

      Config.save()
    end

    return true, value, false
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

    for key, entry in pairs(stored) do
      if !entry.hidden then
        local is_private = Config.is_private(key)
        local has_pending = entry.pending == true
        local clear_pending = resend and (has_pending or Config.needs_restart(key))

        if can_manage == nil and (is_private or has_pending) then
          can_manage = Config.can_manage(self)
        end

        if !is_private or can_manage then
          Cable.send(self, 'fl_config_set_var', key, entry.value)
        elseif resend then
          Cable.send(self, 'fl_config_set_var', key, nil)
        end

        if has_pending and can_manage then
          Cable.send(self, 'fl_config_set_pending', key, true, entry.pending_value)
        elseif clear_pending then
          Cable.send(self, 'fl_config_set_pending', key, false, nil)
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
  -- Clientside variant: runs the ConfigChanged hook and changes the local copy only, nothing is
  -- sent to the server. Does nothing if key is nil.
  -- @param key [String config key]
  -- @param value [Any new value]
  function Config.set(key, value)
    if key != nil then
      local entry = stored[key] or {}
      local old_value = entry.value

      stored[key] = entry
      entry.value = value
      cache[key] = value

      Plugin.call('ConfigChanged', key, old_value, value)
    end
  end

  --- Creates a category for the config menu, or returns the existing one with that ID.
  -- Clientside only. The returned table has the fields category (name and description),
  -- configs, and helper functions that add a config to this category: add_key, add_slider,
  -- add_table_editor, add_textbox, add_checkbox and add_dropdown. The helpers are called
  -- with a dot and take the same arguments as Config.add_to_menu without the category
  -- (and, except for add_key, without the data type).
  -- ```
  -- local category = Config.create_category('flow', 'config.flow.title', 'config.flow.desc')
  --
  -- category.add_slider('flow_walk_speed', 'config.flow.walk_speed.name',
  --   'config.flow.walk_speed.desc', { min_value = 0, max_value = 1024 })
  -- ```
  -- @param id='other' [String category ID]
  -- @param category_name='Other' [String display name or language phrase]
  -- @param category_description='' [String description or language phrase]
  -- @return [Map category table]
  -- @see [Config.add_to_menu]
  function Config.create_category(id, category_name, category_description)
    id = id or 'other'

    if menu_items[id] then return menu_items[id] end

    menu_items[id] = {
      category = { name = category_name or 'Other', description = category_description or '' },
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
  -- shortly after and run the ConfigReceived and ConfigPendingReceived hooks. The server
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
    -- edit configs, and nil arrives for it once they have lost that right.
    -- @param key [String config key]
    -- @param old_value [Any value the client had before]
    -- @param new_value [Any value that has been received]
    hook.Run('ConfigReceived', key, old_value, value)
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
    -- or that its pending value is gone. Pending values belong to the configs that need a
    -- restart and are only sent to the players who may edit configs.
    -- @param key [String config key]
    -- @param is_pending [Boolean whether the config has a pending value now]
    -- @param value [Any value the config takes on the next start of the server, nil if
    --   nothing is pending]
    -- @see [Config.get_pending]
    hook.Run('ConfigPendingReceived', key, is_pending ? true : false, value)
  end)
end

--- Returns the value of a config.
-- The value is cached; the default is only returned, never cached.
-- @param key [String config key]
-- @param default=nil [Any value to return if the config has no value]
-- @return [Any config value, or default]
function Config.get(key, default)
  local value = cache[key]

  if value != nil then
    return value
  end

  value = stored[key]?.value

  if value == nil then
    return default
  end

  cache[key] = value

  return value
end

if SERVER then
  const plugin_keys = { depends = true, depends_development = true, profile = true, exclude = true }
  const import_rank = { [CONFIG_PLUGIN] = 1, [CONFIG_SCHEMA] = 2, [CONFIG_FLUX] = 3 }

  --- Tells whether `Config.import` may set a config: not when it has been changed in game, and
  -- not when a file of higher precedence has set it (`settings.yml` over the schema's .yml file
  -- over a plugin's), whatever order the files are imported in.
  -- @param key [String config key]
  -- @param from_config [Number CONFIG_FLUX, CONFIG_SCHEMA or CONFIG_PLUGIN]
  -- @return [Boolean]
  local function may_import(key, from_config)
    local entry = stored[key]

    if !entry then return true end
    if entry.changed then return false end

    return (import_rank[entry.imported_from] or 0) <= (import_rank[from_config] or 0)
  end

  --- Imports config values from a YAML file or from a table and sets every one of them.
  -- Serverside only. The keys that choose plugins ('profile', 'depends', 'depends_development'
  -- and 'exclude') are skipped, and so is every config that has been changed in game or set by a
  -- file of higher precedence (`settings.yml` over the schema's .yml file over a plugin's) and
  -- every key for which the ShouldConfigImport hook returns a non-nil value. The value of a defined
  -- config goes through `Config.validate` and is skipped with an error naming the key and the
  -- file if it does not pass; in development a key without a definition is reported, and set
  -- all the same.
  -- @param path [String/Map path to a YAML file, or a table of config key to value]
  -- @param from_config=CONFIG_FLUX [Number CONFIG_FLUX, CONFIG_SCHEMA or CONFIG_PLUGIN]
  -- @return [Map the imported table, or nil if the file could not be read or path is
  --   neither a string nor a table]
  function Config.import(path, from_config)
    from_config = from_config or CONFIG_FLUX

    local config_table, source

    if isstring(path) then
      config_table = Flux.read_yaml(path)
      source = path
    elseif istable(path) then
      config_table = path
      source = from_config == CONFIG_FLUX ? 'the configuration of settings.yml' : 'the imported table'
    end

    if !istable(config_table) then return end

    for key, value in pairs(config_table) do
      if plugin_keys[key] or !may_import(key, from_config) then continue end

      --- Called on the server for every key that `Config.import` is about to set.
      -- @param key [String config key]
      -- @param value [Any value read from the imported file or table]
      -- @return [Boolean Return any value other than nil to skip the key and keep its current
      --   value]
      if Plugin.call('ShouldConfigImport', key, value) == nil then
        if definitions[key] then
          local valid, result = Config.validate(key, value)

          if !valid then
            ErrorNoHalt("Not importing the '"..tostring(key).."' config from "..source..': '..t(result)..'\n')

            continue
          end

          value = result
        elseif IS_DEVELOPMENT then
          ErrorNoHalt("The '"..tostring(key).."' config imported from "..source..' has no definition!\n')
        end

        Config.set(key, value, nil, from_config)

        local entry = stored[key]

        entry.imported_from = from_config
        entry.imported_value = copy_value(value)
      end
    end

    return config_table
  end
end

--- Reads config definitions (categories and configs) from a YAML file or from a table.
-- On the server a config is set to its default_value when it has no value yet, or when it
-- was never changed in game and still holds the default of the definition it had before,
-- so a code refresh keeps the values changed in game and imported from files; its definition
-- is stored either way.
-- On the client the categories and configs are added to the config menu. Both sides keep
-- the definitions for `Config.get_definition`. Besides the fields shown below a config can
-- be marked with `hidden`, `static`, `private` and `needs_restart`, which are described at
-- the top of this file. A config of the `color` type holds a Color and writes its default
-- value as a map of r, g, b and, optionally, a.
-- ```
-- Config.read('gamemodes/'..PACKAGE.__path__..'config/config.yml')
--
-- Config.read({
--   categories = {
--     flow = { name = 'config.flow.title', description = 'config.flow.desc' }
--   },
--   configs = {
--     flow_walk_speed = {
--       name = 'config.flow.walk_speed.name',
--       description = 'config.flow.walk_speed.desc',
--       category = 'flow',
--       type = 'number',
--       min_value = 0,
--       max_value = 1024,
--       default_value = 100
--     }
--   }
-- })
-- ```
-- @param path [String/Map path to a YAML file relative to the game folder, read on the server
--   only, or the already parsed definitions]
-- @param _from_config=nil [Number ignored]
-- @return [Map the definitions table, or nil if path is neither a string nor a table or the
--   file could not be read]
function Config.read(path, _from_config)
  local config_table

  if SERVER and isstring(path) then
    config_table = Flux.read_yaml(path)
  elseif istable(path) then
    config_table = path
  end

  if !istable(config_table) then return end

  if CLIENT and istable(config_table.categories) then
    for category, data in pairs(config_table.categories) do
      Config.create_category(category, data.name, data.description)
    end
  end

  if istable(config_table.configs) then
    for name, data in pairs(config_table.configs) do
      local previous = definitions[name]

      definitions[name] = data

      if SERVER then
        if takes_default(stored[name], previous) then
          Config.set(name, default_value(data), data.hidden)
        end

        table.safe_merge(stored[name], data)
      else
        Config.add_to_menu(data.category or 'other', name, data.name, data.description, data.type, data)
      end
    end
  end

  return config_table
end

--- Reads the config definitions of every .yml file in a folder of a plugin, of the schema or
-- of a package. The server reads the files with `Config.read` and keeps what they define in
-- `Flux.shared.configs`, from where it reaches the clients, which read that copy instead of
-- the files. Called by the plugin loader for the `config` folder of every plugin and of the
-- schema, and by the packages that define configs.
-- ```
-- Config.include_folder(FLUX_PATH..'plugins/doors/plugin/config')
-- Config.include_folder(PACKAGE.__path__..'config')
-- ```
-- @param folder [String folder of the .yml files, relative to the gamemodes folder]
function Config.include_folder(folder)
  folder = folder:gsub('/$', '')

  if SERVER then
    local files, _folders = file.Find('gamemodes/'..folder..'/*.yml', 'GAME')

    if !files then return end

    local configs = {}

    for _, file_name in ipairs(files) do
      local definitions_read = Config.read('gamemodes/'..folder..'/'..file_name)

      if definitions_read then
        table.Merge(configs, definitions_read)
      end
    end

    Flux.shared.configs[folder] = configs
  elseif Flux.shared.configs[folder] then
    Config.read(Flux.shared.configs[folder])
  end
end
