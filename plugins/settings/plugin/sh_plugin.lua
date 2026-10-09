--- Settings gives every player options of their own that they change in the Settings tab of
-- the tab menu, as opposed to the configs of the `Config` library, which belong to the server.
-- A setting is registered with `ClientSettings:register_setting` from the
-- `RegisterClientSettings` hook. It has a type ('boolean', 'number', 'choice' or 'string'
-- out of the box, more can be added with `ClientSettings:register_type`), a default value,
-- a category, a name and a description, and optionally a function that decides whether the
-- player sees it in the menu and a function that is called when its value changes.
--
-- The values live on the client. They are kept in the 'settings' file of the client data
-- store (`Data.save`), so they follow the player from session to session and from server to
-- server. `ClientSettings:get` reads one and returns the default of the setting for as long
-- as the player has not changed it; `ClientSettings:set` and `ClientSettings:reset` change
-- one and run the `ClientSettingChanged` hook.
--
-- A setting that is registered as `networked` is also sent to the server: all of them when
-- the player joins, and one whenever it changes. The server checks what it receives against
-- the definition of the setting, runs `PlayerSettingChanged` and answers
-- `Player:get_setting`. For that to work a networked setting has to be registered on both
-- the server and the client, which is the case when it is registered from shared code.
-- @module [ClientSettings]

PLUGIN:set_global('ClientSettings')

local stored = ClientSettings.stored or {}
local types = ClientSettings.types or {}
ClientSettings.stored = stored
ClientSettings.types = types

--- Registers a type of settings: how the values of such settings are checked and which
-- control edits them in the settings menu.
-- ```
-- ClientSettings:register_type('boolean', {
--   -- Optional. Fills in the fields of a setting of this type when it is registered;
--   -- return false to refuse the setting.
--   setup = function(setting) end,
--   -- Optional. Returns the default of a setting that does not define a valid one.
--   get_default = function(setting)
--     return false
--   end,
--   -- Returns the value if it is valid for the setting (it may correct it first),
--   -- or nil if it is not.
--   sanitize = function(setting, value)
--     if isbool(value) then
--       return value
--     end
--   end,
--   -- Clientside. Creates the control of the setting for the settings menu. The control
--   -- has to show the given value and call on_change with the new one when the player
--   -- changes it.
--   create_control = function(setting, parent, value, on_change)
--     -- ...
--   end
-- })
-- ```
-- The values of a setting have to be booleans, numbers or strings.
-- @param id [String unique type id]
-- @param data [Map type definition: sanitize(setting, value) and the optional
--   setup(setting), get_default(setting) and create_control(setting, parent, value, on_change)]
function ClientSettings:register_type(id, data)
  if !isstring(id) or !istable(data) or !isfunction(data.sanitize) then return end

  data.id = id

  types[id] = data
end

--- Returns the definition of a type of settings.
-- @param id [String type id]
-- @return [Map type definition, or nil if there is no such type]
function ClientSettings:find_type(id)
  return types[id]
end

--- Registers a setting. Meant to be called from the `RegisterClientSettings` hook.
-- Registering an ID again replaces the setting but keeps its place in the menu.
-- ```
-- function MyPlugin:RegisterClientSettings()
--   ClientSettings:register_setting('my_plugin_clock', {
--     type = 'boolean',
--     default = true,
--     category = 'settings.categories.interface',
--     name = 'settings.my_plugin_clock.name',
--     description = 'settings.my_plugin_clock.desc'
--   })
--
--   ClientSettings:register_setting('my_plugin_clock_scale', {
--     type = 'number',
--     default = 1,
--     min = 0.5,
--     max = 2,
--     decimals = 1,
--     category = 'settings.categories.interface',
--     name = 'settings.my_plugin_clock_scale.name',
--     -- Only listed in the menu while the clock is turned on.
--     visible = function(setting)
--       return ClientSettings:get('my_plugin_clock')
--     end,
--     on_change = function(value, old_value, setting)
--       MyPlugin:rebuild_clock(value)
--     end
--   })
--
--   ClientSettings:register_setting('my_plugin_clock_format', {
--     type = 'choice',
--     default = '24h',
--     choices = {
--       { value = '12h', name = 'settings.my_plugin_clock_format.twelve' },
--       { value = '24h', name = 'settings.my_plugin_clock_format.twenty_four' }
--     },
--     category = 'settings.categories.interface',
--     name = 'settings.my_plugin_clock_format.name',
--     -- The server can read it with target:get_setting('my_plugin_clock_format').
--     networked = true
--   })
-- end
-- ```
-- @param id [String unique setting id, also the key its value is saved under]
-- @param data [Map setting definition. type (String) is required. Optional:
--   default (Any, the type decides if left out), category (String phrase,
--   'settings.categories.general' by default), name (String phrase, the id by default),
--   description (String phrase, shown as a tooltip), networked (Boolean send the value to
--   the server), visible (Function(setting) return a falsy value to leave the setting out of
--   the menu; clientside), on_change (Function(value, old_value, setting) called on the
--   client when the value changes). By type: min (0), max (100) and decimals (0) for
--   'number'; choices (List of values or of { value, name } tables) for 'choice';
--   max_length (128) for 'string']
-- @return [Map the registered setting, or nil if it could not be registered]
function ClientSettings:register_setting(id, data)
  if !isstring(id) or !istable(data) then return end

  local type_data = types[data.type]

  if !type_data then
    ErrorNoHalt("Not registering the '"..id.."' setting! Unknown type: '"..tostring(data.type).."'!\n")

    return
  end

  if type_data.setup and type_data.setup(data) == false then
    ErrorNoHalt("Not registering the '"..id.."' setting! Its definition is not valid!\n")

    return
  end

  local default = data.default

  if default != nil then
    default = type_data.sanitize(data, default)
  end

  if default == nil and type_data.get_default then
    default = type_data.get_default(data)
  end

  if default == nil then
    ErrorNoHalt("Not registering the '"..id.."' setting! It has no valid default value!\n")

    return
  end

  local existing = stored[id]

  if existing then
    data.order = existing.order
  else
    self.setting_count = (self.setting_count or 0) + 1

    data.order = self.setting_count
  end

  data.id = id
  data.default = default
  data.name = data.name or id
  data.category = data.category or 'settings.categories.general'
  data.networked = data.networked == true

  stored[id] = data

  if CLIENT then
    self:load_value(id)
  end

  return data
end

--- Removes a setting, so that it is no longer listed in the menu, read or networked.
-- The value the player has saved for it is kept in case the setting comes back.
-- @param id [String setting id]
function ClientSettings:remove_setting(id)
  stored[id] = nil

  if CLIENT then
    self:load_value(id)
  end
end

--- Returns every registered setting.
-- @return [Map setting definitions keyed by setting id]
function ClientSettings:all()
  return stored
end

--- Returns the definition of a registered setting.
-- @param id [String setting id]
-- @return [Map setting definition, or nil if it is not registered]
function ClientSettings:find(id)
  return stored[id]
end

--- Checks a value against the definition of a setting.
-- @param id [String setting id]
-- @param value [Any value to check]
-- @return [Any the value as the setting would store it (a number is clamped and rounded,
--   for example), or nil if the setting is not registered or the value is not valid for it]
function ClientSettings:sanitize(id, value)
  local setting = stored[id]

  if !setting or value == nil then return end

  local type_data = types[setting.type]

  if !type_data then return end

  return type_data.sanitize(setting, value)
end

require_relative 'sh_types'
require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_plugin'

--- Runs the RegisterClientSettings hook so that plugins and the schema can register their
-- settings. On the client it then sends the networked settings to the server again if they
-- have been sent before, which is the case after a code refresh.
function ClientSettings:OnSchemaLoaded()
  --- Lets plugins and the schema register their settings with
  -- `ClientSettings:register_setting`. Called on the server and the client once all plugins
  -- and the schema have been loaded, and again on every code refresh. Register a setting on
  -- both realms if it is networked; a setting that is not can be registered on the client
  -- only. A type added with `ClientSettings:register_type` has to be registered before the
  -- settings that use it. Do not return anything from the handler, or the plugins after it
  -- are not asked.
  hook.Run('RegisterClientSettings')

  if CLIENT and self.ready then
    self:sync_all()
  end
end
