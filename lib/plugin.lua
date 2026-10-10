--- Plugin loads plugins and the schema and dispatches hooks to them.
-- A plugin is a folder with a `plugin.yml` and a `plugin` subfolder, or a single .lua file;
-- the schema is loaded in much the same way and takes part in hooks like one more plugin.
-- While a plugin is being included the `PLUGIN` global holds its `PluginInstance`, and
-- besides the main file a set of extra folders (`lib`, `config`, `entities`, `themes` and so
-- on, see `Plugin.add_extra`) is included automatically. Every function of a registered
-- plugin is put into the hook cache under its name, and `hook.Call` is overridden to run
-- those functions before the regular hooks, so defining `function PLUGIN:PlayerSpawn(target)`
-- is all it takes to handle a hook. `Plugin.call` runs a hook without the gamemode's own
-- handlers, and `Plugin.add_hooks` registers a table of handlers that does not belong to a
-- plugin.
--
-- Plugins can be disabled. A disabled plugin is not included at all, neither on the server
-- nor on the clients, and a plugin that depends on it is not loaded either, while the schema
-- simply goes without it. The list of disabled plugins is read from the 'disabled_plugins'
-- data file when the server starts and stays the same until it stops:
-- `Plugin.set_disabled`, `Plugin.disable` and `Plugin.enable` only change what is saved, so
-- THEIR EFFECT IS DELAYED UNTIL THE SERVER RESTARTS (a change of the map restarts the
-- gamemode and counts as well). `Plugin.is_disabled` tells whether a plugin is disabled right
-- now, `Plugin.disabled_on_restart` whether it will be after the restart, and
-- `Plugin.known` lists every plugin together with both states. Plugins are
-- referred to by the name they are required by in `depends`: the name of the folder, or the
-- file name of a single-file plugin without the realm prefix and the extension (see
-- `Plugin.normalize_id`).

if Plugin then return end

require_relative 'plugin_instance'

local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local istable = istable
local isstring = isstring
local isfunction = isfunction
local tostring = tostring

mod 'Plugin'

local stored = {}
local unloaded = {}
local hooks_cache = {}
local load_cache = {}
local schema_depends = {}
local disabled_loaded = false
local pending_disabled
local default_extras = {
  'lib',
  'lib/meta',
  'lib/classes',
  'models',
  'classes',
  'meta',
  'config',
  'languages',
  'controllers',
  'views', 'views/lumen',
  'tools',
  'themes',
  'entities',
  'migrations'
}

local extras = table.Copy(default_extras)

--- Returns all registered plugins, the schema included.
-- @return [Map plugin path to plugin object]
function Plugin.all()
  return stored
end

--- Returns the hook cache.
-- @return [Map hook name to a List of entries shaped { callback, object, id = id }]
function Plugin.get_cache()
  return hooks_cache
end

--- Clears the hook and load caches and resets the extra folders, ready for a code refresh.
-- Does nothing before Flux has initialized. On a lite refresh only the entries of plugins
-- whose path does not contain 'flux' are dropped.
function Plugin.clear_cache()
  if !Flux.initialized then return end

  Plugin.clear_extras()

  if !LITE_REFRESH then
    hooks_cache = {}
    load_cache = {}
  else
    for hook_name, hook_table in pairs(hooks_cache) do
      for k, obj in ipairs(hook_table) do
        if istable(obj) and istable(obj[2]) and isstring(obj[2].path) and !obj[2].path:include('flux') then
          load_cache[obj[2].id] = nil
          hooks_cache[hook_name][k] = nil
        end
      end
    end
  end
end

--- Forgets which plugins have been loaded, so that they can be included again.
function Plugin.clear_load_cache()
  load_cache = {}
end

--- Resets the list of extra plugin folders to the defaults.
function Plugin.clear_extras()
  extras = table.Copy(default_extras)
end

--- Adds every function of a table to the hook cache under the key it is stored at,
-- so that hook.Call calls it with the table as self.
-- @param obj [Map table with functions named after hooks, e.g. a plugin object]
-- @param id=nil [String ID to store with the entries, see Plugin.remove_hooks]
function Plugin.cache_functions(obj, id)
  for k, v in pairs(obj) do
    if isfunction(v) then
      local handlers = hooks_cache[k] or {}

      hooks_cache[k] = handlers
      handlers[#handlers + 1] = { v, obj, id = id }
    end
  end
end

--- Registers the functions of a table as hook handlers.
-- ```
-- local hooks = {}
--
-- function hooks:PlayerButtonDown(actor, key)
--   Cable.send(actor, 'fl_bind_pressed', key)
-- end
--
-- Plugin.add_hooks('FLBinds', hooks)
-- ```
-- @param id [String unique ID of this set of hooks]
-- @param obj [Map table with functions named after hooks]
function Plugin.add_hooks(id, obj)
  Plugin.cache_functions(obj, id)
end

--- Removes all hook handlers that have been registered under an ID.
-- @param id [String ID that was passed to Plugin.add_hooks]
function Plugin.remove_hooks(id)
  for k, v in pairs(hooks_cache) do
    for k2, v2 in ipairs(v) do
      if v2.id and v2.id == id then
        hooks_cache[k][k2] = nil
      end
    end
  end
end

--- Finds a registered plugin by its path, ID, folder or name.
-- @param id [String plugin path, ID, folder or name]
-- @return [Plugin the plugin, String the path it is stored under; nothing if not found]
function Plugin.find(id)
  if stored[id] then
    return stored[id], id
  else
    for k, v in pairs(stored) do
      if v.id == id or v:get_folder() == id or v:get_path() == id or v:get_name() == id then
        return v, k
      end
    end
  end
end

--- Unhooks a plugin by removing its functions from the hook cache.
-- Calls the plugin's on_unhook method first, if it has one.
-- @param id [String/Plugin plugin path, ID, folder or name, or the plugin object itself]
function Plugin.remove_from_cache(id)
  local plugin_table = Plugin.find(id) or (istable(id) and id)

  if plugin_table then
    if plugin_table.on_unhook then
      local success, exception = pcall(plugin_table.on_unhook, plugin_table)

      if !success then
        error_with_traceback(
          'Plugin#on_unhook method has failed to run for '..
          tostring(plugin_table)..
          '!\n'..
          tostring(exception)
        )
      end
    end

    for k, v in pairs(plugin_table) do
      if !isfunction(v) or !hooks_cache[k] then continue end

      for index, tab in ipairs(hooks_cache[k]) do
        if tab[2] == plugin_table then
          table.remove(hooks_cache[k], index)
          break
        end
      end
    end
  end
end

--- Caches the hooks of an existing plugin again.
-- Calls the plugin's on_recache method first, if it has one.
-- @param id [String plugin path, ID, folder or name]
function Plugin.recache(id)
  local plugin_table = Plugin.find(id)

  if plugin_table then
    if plugin_table.on_recache then
      local success, exception = pcall(plugin_table.on_recache, plugin_table)

      if !success then
        error_with_traceback(
          'Plugin#on_recache method has failed to run! '..
          tostring(plugin_table)..
          '\n'..
          tostring(exception)
        )
      end
    end

    Plugin.cache_functions(plugin_table)
  end
end

--- Removes a plugin entirely: unhooks it and deletes it from the registered plugins.
-- Calls the plugin's on_removed method first, if it has one.
-- @param id [String plugin path, ID, folder or name]
function Plugin.remove(id)
  local plugin_table, plugin_id = Plugin.find(id)

  if plugin_table then
    if plugin_table.on_removed then
      local success, exception = pcall(plugin_table.on_removed, plugin_table)

      if !success then
        error_with_traceback(
          'Plugin#on_removed method has failed to run! '..
          tostring(plugin_table)..
          '\n'..
          tostring(exception)
        )
      end
    end

    Plugin.remove_from_cache(id)

    stored[plugin_id] = nil
  end
end

--- Turns a plugin path, folder, file name or dependency name into the ID that the plugin has
-- on the list of disabled plugins and in `Plugin.known`. That is the name a plugin is
-- required by in `depends`: the name of its folder, or the file name of a single-file
-- plugin without the realm prefix and the extension.
-- ```
-- Plugin.normalize_id('flux/plugins/doors')              -- 'doors'
-- Plugin.normalize_id('flux/plugins/doors/plugin')       -- 'doors'
-- Plugin.normalize_id('flux/plugins/cl_crosshair.lua')   -- 'crosshair'
-- Plugin.normalize_id('crosshair')                       -- 'crosshair'
-- ```
-- @param id [String plugin path, folder, file name or dependency name]
-- @return [String normalized ID, or nil if id is not a string or nothing is left of it]
function Plugin.normalize_id(id)
  if !isstring(id) then return end

  local name = string.gsub(id, '/plugin$', '')

  name = name:match('([^/\\]+)$') or name

  if name:sub(-4) == '.lua' then
    name = name:sub(1, -5)

    local prefix = name:sub(1, 3)

    if prefix == 'sv_' or prefix == 'sh_' or prefix == 'cl_' then
      name = name:sub(4)
    end
  end

  if name == '' then return end

  return name
end

--- Returns the set of plugins that are saved as disabled, which is what applies after the
-- next restart. On the client it starts out as a copy of what the server has shared.
-- @return [Map normalized plugin ID to true]
local function pending_set()
  if !pending_disabled then
    pending_disabled = table.Copy(Flux.shared.disabled_plugins or {})
  end

  return pending_disabled
end

--- Records that a plugin was not loaded and why, in the table shared with clients.
-- Does nothing on the client.
-- @param info [Map plugin info with the id, name, description, author, version, path,
--   single_file and depends fields]
-- @param reason [String 'disabled', 'dependency' or 'environment']
local function mark_unloaded(info, reason)
  if !SERVER then return end

  local id = Plugin.normalize_id(info.id)

  if !id then return end

  Flux.shared.unloaded_plugins = Flux.shared.unloaded_plugins or {}
  Flux.shared.unloaded_plugins[id] = {
    id = id,
    name = info.name,
    description = info.description,
    author = info.author,
    version = info.version,
    path = info.path,
    single_file = info.single_file or false,
    depends = info.depends,
    reason = reason
  }
end

--- Checks whether a plugin cannot be relied upon as a dependency in this session: it is
-- disabled, or it was not loaded because a dependency of its own is disabled or missing.
-- @param name [String plugin path, ID or dependency name]
-- @return [Boolean]
local function is_unavailable(name)
  if Plugin.is_disabled(name) then
    return true
  end

  local id = Plugin.normalize_id(name)
  local info = id and Flux.shared.unloaded_plugins and Flux.shared.unloaded_plugins[id]

  return istable(info) and info.reason != 'environment'
end

--- Gathers what is known about every plugin the loader has come across in this session:
-- the loaded ones and the ones that were skipped. Plugins that are on the list of disabled
-- plugins without having been come across, for instance because their files are gone, are
-- included with nothing but their ID.
-- @return [Map normalized plugin ID to a table with the id, name, description, author,
--   version, path, single_file, depends, loaded and reason fields]
local function known_info()
  local known = {}
  local unloaded_info = Flux.shared.unloaded_plugins or {}

  for path, info in pairs(Flux.shared.plugin_info or {}) do
    local id = Plugin.normalize_id(path)

    if id then
      local instance = stored[path]
      local name = instance and instance:get_name() or info.name

      if !isstring(name) or name == 'Unknown Plugin' then
        name = id
      end

      known[id] = {
        id = id,
        name = name,
        description = instance and instance:get_description() or info.description,
        author = instance and instance:get_author() or info.author,
        version = info.version,
        path = path,
        single_file = info.single_file or false,
        depends = istable(info.depends) and info.depends or {},
        loaded = unloaded_info[id] == nil,
        reason = unloaded_info[id] and unloaded_info[id].reason
      }
    end
  end

  for id, info in pairs(unloaded_info) do
    if !known[id] then
      known[id] = {
        id = id,
        name = isstring(info.name) and info.name or id,
        description = info.description,
        author = info.author,
        version = info.version,
        path = info.path,
        single_file = info.single_file or false,
        depends = istable(info.depends) and info.depends or {},
        loaded = false,
        reason = info.reason
      }
    end
  end

  for id, v in pairs(pending_set()) do
    if !known[id] then
      known[id] = {
        id = id,
        name = id,
        single_file = false,
        depends = {},
        loaded = false,
        reason = 'disabled'
      }
    end
  end

  return known
end

--- Works out who depends on which plugin: the schema, and every plugin that is not saved as
-- disabled.
-- @param known [Map result of known_info]
-- @return [Map normalized plugin ID to a List of the names of its dependents]
local function collect_dependents(known)
  local dependents = {}
  local pending = pending_set()

  for k, v in ipairs(schema_depends) do
    local id = Plugin.normalize_id(v)

    if id then
      local list = dependents[id] or {}

      dependents[id] = list

      if #list == 0 then
        list[1] = Flux.get_schema_name()
      end
    end
  end

  for id, info in pairs(known) do
    if !pending[id] then
      for k, v in ipairs(info.depends) do
        local dependency = Plugin.normalize_id(v)

        if dependency and dependency != id then
          local list = dependents[dependency] or {}

          dependents[dependency] = list

          if !table.HasValue(list, info.name) then
            list[#list + 1] = info.name
          end
        end
      end
    end
  end

  return dependents
end

--- Checks whether a plugin is disabled in this session, that is whether the loader skips it.
-- This is the state the server has started with: disabling or enabling a plugin does not
-- change it until the server restarts, see `Plugin.disabled_on_restart` for the saved state.
-- @param id [String plugin path, folder, ID or dependency name, see Plugin.normalize_id]
-- @return [Boolean]
function Plugin.is_disabled(id)
  local disabled = Flux.shared.disabled_plugins

  id = Plugin.normalize_id(id)

  if disabled and id then
    return disabled[id] == true
  end

  return false
end

--- Checks whether a plugin is saved as disabled, that is whether it will be disabled after
-- the next restart of the server. Differs from `Plugin.is_disabled` between a call of
-- `Plugin.set_disabled` and the restart. On the client this follows the server.
-- @param id [String plugin path, folder, ID or dependency name, see Plugin.normalize_id]
-- @return [Boolean]
function Plugin.disabled_on_restart(id)
  id = Plugin.normalize_id(id)

  return id != nil and pending_set()[id] == true
end

--- Lists the schema and the plugins that depend on a plugin, by name. Plugins that are
-- saved as disabled do not count.
-- @param id [String plugin path, folder, ID or dependency name, see Plugin.normalize_id]
-- @return [List<String> names of the dependents, the schema's name first; empty if there
--   are none]
function Plugin.dependents(id)
  id = Plugin.normalize_id(id)

  if !id then
    return {}
  end

  return collect_dependents(known_info())[id] or {}
end

--- Lists every plugin the loader has come across in this session, loaded or not, with its
-- state. The schema is not on the list, and neither are plugins that nothing has tried to
-- load. Works on both the server and the client, which is what a plugin manager page is
-- meant to be built from. Every entry has the fields:
--
-- * `id`: normalized ID, the one to pass to `Plugin.set_disabled`.
-- * `name`, `description`, `author`, `version`, `path`, `single_file`: plugin info. The name
--   falls back to the ID where the plugin does not set one on this realm.
-- * `depends`: List of the names of the plugins and packages it depends on.
-- * `loaded`: whether the server has loaded the plugin in this session.
-- * `reason`: why it was not loaded: 'disabled', 'dependency' (a dependency is disabled or
--   missing) or 'environment' (not meant for this environment); nil if it was loaded.
-- * `disabled`: whether the plugin is saved as disabled, see `Plugin.disabled_on_restart`.
-- * `restart_required`: true if `disabled` differs from the state the plugin has in this
--   session, which means that the server has to restart for the change to take effect.
-- * `required_by`: List of the names of the schema and the plugins that depend on it, see
--   `Plugin.dependents`.
-- * `schema_dependency`: whether the schema depends on it.
-- @return [List<Map> plugin entries sorted by name]
function Plugin.known()
  local list = {}
  local known = known_info()
  local dependents = collect_dependents(known)
  local pending = pending_set()
  local schema_ids = {}

  for k, v in ipairs(schema_depends) do
    local id = Plugin.normalize_id(v)

    if id then
      schema_ids[id] = true
    end
  end

  for id, info in pairs(known) do
    info.disabled = pending[id] == true
    info.restart_required = info.disabled != Plugin.is_disabled(id)
    info.required_by = dependents[id] or {}
    info.schema_dependency = schema_ids[id] == true

    list[#list + 1] = info
  end

  table.sort(list, function(first, second)
    local first_name, second_name = first.name:lower(), second.name:lower()

    if first_name == second_name then
      return first.id < second.id
    end

    return first_name < second_name
  end)

  return list
end

if SERVER then
  --- Reads the list of disabled plugins from the 'disabled_plugins' data file into
  -- Flux.shared.disabled_plugins, from where it reaches the clients. Serverside only.
  -- The file is read once per start of the server: later calls, including the ones made
  -- when the code is refreshed, return the list that is already in effect.
  -- @return [Map normalized plugin ID to true]
  function Plugin.load_disabled()
    if disabled_loaded then
      return Flux.shared.disabled_plugins
    end

    local loaded = Data.load('disabled_plugins', {})
    local disabled = {}

    if istable(loaded) then
      for k, v in pairs(loaded) do
        local id

        if isstring(v) then
          id = Plugin.normalize_id(v)
        elseif v == true then
          id = Plugin.normalize_id(tostring(k))
        end

        if id then
          disabled[id] = true
        end
      end
    end

    Flux.shared.disabled_plugins = disabled
    pending_disabled = table.Copy(disabled)
    disabled_loaded = true

    return disabled
  end

  --- Lists the plugins that are saved as disabled.
  -- @return [List<String> normalized plugin IDs in alphabetical order]
  local function pending_list()
    local list = {}

    for k, v in pairs(pending_set()) do
      list[#list + 1] = k
    end

    table.sort(list)

    return list
  end

  --- Disables or enables a plugin and saves the choice. Serverside only.
  -- THE CHANGE TAKES EFFECT AFTER THE SERVER HAS RESTARTED OR CHANGED THE MAP: the plugin
  -- stays loaded (or unloaded) until then, `Plugin.is_disabled` keeps returning the old
  -- state and `Plugin.disabled_on_restart` returns the new one. Once it is in effect a
  -- disabled plugin is not included on the server or on the clients, and neither are the
  -- plugins that depend on it.
  --
  -- A plugin that the schema or a plugin that is not disabled depends on is not disabled
  -- unless force is true; the names of the dependents are returned instead. The function
  -- does not check who is asking: do that before calling it. The new state is sent to all
  -- clients and the OnPluginStateChanged hook is run.
  -- ```
  -- local success, phrase, dependents = Plugin.set_disabled('doors', true)
  --
  -- if !success then
  --   actor:notify(phrase, { plugins = table.concat(dependents or {}, ', ') })
  -- end
  -- ```
  -- @param id [String plugin path, folder, ID or dependency name, see Plugin.normalize_id]
  -- @param disabled [Boolean true to disable the plugin, false to enable it]
  -- @param force=false [Boolean disable the plugin even if something depends on it]
  -- @return [Boolean whether the state is saved as asked, String language phrase of the
  --   error ('error.plugin.unknown' or 'error.plugin.required'), List<String> names of the
  --   dependents if the error is 'error.plugin.required']
  function Plugin.set_disabled(id, disabled, force)
    local known = known_info()

    id = Plugin.normalize_id(id)

    if !id or !known[id] then
      return false, 'error.plugin.unknown'
    end

    local pending = pending_set()

    disabled = disabled and true or false

    if (pending[id] == true) == disabled then
      return true
    end

    if disabled and !force then
      local dependents = collect_dependents(known)[id]

      if dependents and #dependents > 0 then
        return false, 'error.plugin.required', dependents
      end
    end

    pending[id] = disabled or nil

    Data.save('disabled_plugins', pending_list())
    Cable.send(nil, 'fl_plugin_set_disabled', id, disabled)

    --- Called when a plugin has been disabled or enabled with `Plugin.set_disabled`: on the
    -- server right after the new state has been saved, and on every client once the server
    -- has told it. The plugin itself is not loaded or unloaded at this point, the change
    -- takes effect after the server has restarted.
    -- @param id [String normalized ID of the plugin, see `Plugin.normalize_id`]
    -- @param disabled [Boolean true if the plugin will be disabled after the restart, false
    --   if it will be enabled]
    hook.Run('OnPluginStateChanged', id, disabled)

    return true
  end

  --- Disables a plugin. Serverside only. Shorthand for `Plugin.set_disabled(id, true, force)`.
  -- The plugin keeps running until the server restarts or changes the map.
  -- @param id [String plugin path, folder, ID or dependency name, see Plugin.normalize_id]
  -- @param force=false [Boolean disable the plugin even if something depends on it]
  -- @return [Boolean whether the plugin is saved as disabled, String language phrase of the
  --   error, List<String> names of the dependents]
  -- @see [Plugin.set_disabled]
  function Plugin.disable(id, force)
    return Plugin.set_disabled(id, true, force)
  end

  --- Enables a disabled plugin. Serverside only. Shorthand for
  -- `Plugin.set_disabled(id, false)`. The plugin is loaded when the server restarts or
  -- changes the map, provided that the plugins it depends on are enabled as well.
  -- @param id [String plugin path, folder, ID or dependency name, see Plugin.normalize_id]
  -- @return [Boolean whether the plugin is saved as enabled, String language phrase of the
  --   error]
  -- @see [Plugin.set_disabled]
  function Plugin.enable(id)
    return Plugin.set_disabled(id, false)
  end

  --- Sends the list of plugins that are saved as disabled to a player, so that their client
  -- knows about the changes made since the server has started. Serverside only.
  -- @param target [Player player to send the list to; every player if nil]
  function Plugin.send_disabled(target)
    Cable.send(target, 'fl_plugin_disabled_list', pending_list())
  end
else
  Cable.receive('fl_plugin_set_disabled', function(id, disabled)
    if !isstring(id) then return end

    pending_set()[id] = disabled and true or nil

    hook.Run('OnPluginStateChanged', id, disabled and true or false)
  end)

  Cable.receive('fl_plugin_disabled_list', function(list)
    pending_disabled = {}

    if istable(list) then
      for k, v in ipairs(list) do
        if isstring(v) then
          pending_disabled[v] = true
        end
      end
    end
  end)
end

--- Checks whether a plugin has already been loaded.
-- @param obj [Plugin/String plugin object or plugin ID]
-- @return [Boolean true if loaded; nil if not; false if obj is neither a table nor a string]
function Plugin.loaded(obj)
  if istable(obj) then
    return load_cache[obj.id]
  elseif isstring(obj) then
    return load_cache[obj]
  end

  return false
end

--- Registers a plugin: caches its hooks, calls its OnPluginLoaded method, stores it under
-- its path and marks it as loaded.
-- On the server this also imports the schema's .yml config when the schema is registered,
-- and shares the info of single-file plugins with clients.
-- @param obj [Plugin plugin object to register]
function Plugin.register(obj)
  Plugin.cache_functions(obj)

  if SERVER then
    if SCHEMA == obj then
      local folder_name = obj.folder:trim_end('/schema')
      local file_path = 'gamemodes/'..folder_name..'/'..folder_name..'.yml'

      if file.Exists(file_path, 'GAME') then
        Flux.dev_print('Importing config: '..file_path)

        Config.import(file_path, CONFIG_PLUGIN)
      end
    end

    -- Single-file plugins must be made known here.
    if obj.single_file then
      Flux.shared.plugin_info[obj.folder] = {
        name = obj.name,
        description = obj.description,
        author = obj.author,
        version = obj.version,
        folder = obj.folder,
        single_file = obj.single_file,
        plugin_main = obj.folder,
        depends = obj.depends,
        depends_development = obj.depends_development
      }
    end

    local id = SCHEMA != obj and Plugin.normalize_id(obj.id)

    if id and Flux.shared.unloaded_plugins then
      Flux.shared.unloaded_plugins[id] = nil
    end
  end

  if isfunction(obj.OnPluginLoaded) then
    obj:OnPluginLoaded()
  end

  stored[obj:get_path()] = obj
  load_cache[obj.id] = true
end

--- Includes a plugin from a folder or from a single .lua file and registers it.
-- Reads plugin.yml on the server, checks the plugin's environment and dependencies, includes
-- its extra folders and its main file. The PLUGIN global is set while the plugin loads.
-- A disabled plugin is skipped, and so is a plugin with a dependency that is disabled or
-- was not loaded because of its own dependencies.
-- @param path [String plugin folder or .lua file, relative to the LUA search path]
-- @return [Map plugin info, or nil if the plugin was not loaded (already loaded, disabled,
--   wrong environment or missing dependency)]
function Plugin.include(path)
  local id = File.name(path)
  local ext = File.ext(id)
  local data = {}
  data.id = id
  data.path = path
  data.folder = path
  data.single_file = ext == 'lua'

  if Plugin.loaded(id) then
    return
  end

  if Plugin.is_disabled(id) then
    if SERVER then
      if !data.single_file and file.Exists(path..'/plugin.yml', 'LUA') then
        table.safe_merge(data, YAML.eval(file.Read(path..'/plugin.yml', 'LUA')) or {})
      end

      mark_unloaded(data, 'disabled')
    end

    Flux.dev_print('Skipping disabled plugin: '..path)

    return
  end

  Flux.dev_print('Loading plugin: '..path)

  if !data.single_file and SERVER then
    if file.Exists(path..'/plugin.yml', 'LUA') then
      local data_table = YAML.eval(file.Read(path..'/plugin.yml', 'LUA'))
        data_table.folder = path..'/plugin'
        data_table.plugin_main = 'sh_plugin.lua'

        if file.Exists(data_table.folder..'/sh_'..(data_table.name or id)..'.lua', 'LUA') then
          data_table.plugin_main = 'sh_'..(data_table.name or id)..'.lua'
        end
      table.safe_merge(data, data_table)

      Flux.shared.plugin_info[path] = data
    end
  else
    table.safe_merge(data, Flux.shared.plugin_info[path] or {})
  end

  if data.environment then
    if isstring(data.environment) and ENV['FLUX_ENV'] != data.environment then
      mark_unloaded(data, 'environment')

      return
    elseif istable(data.environment) and !table.HasValue(data.environment, ENV['FLUX_ENV']) then
      mark_unloaded(data, 'environment')

      return
    end
  end

  if istable(data.depends) then
    if IS_DEVELOPMENT then
      table.map(data.depends_development or {}, function(v)
        table.insert(data.depends, v)
      end)
    end

    for k, v in ipairs(data.depends) do
      if !Plugin.require(v) then
        if !is_unavailable(v) then
          ErrorNoHalt("Not loading the '"..tostring(path).."' plugin! Dependency missing: '"..tostring(v).."'!\n")
        elseif SERVER then
          print("Not loading the '"..tostring(path).."' plugin: the '"..tostring(v).."' plugin is not available.")
        end

        mark_unloaded(data, 'dependency')

        return
      end
    end
  end

  PLUGIN = PluginInstance.new(id, data)

  if stored[path] then
    PLUGIN = stored[path]
  end

  Plugin.include_folders(data.folder)

  if !data.single_file then
    require_relative(data.folder..'/'..data.plugin_main)
  else
    if file.Exists(path, 'LUA') then
      require_relative(path)
    end
  end

  PLUGIN:register()
  PLUGIN = nil

  return data
end

--- Includes the active schema: loads its dependencies, sh_schema.lua, extra folders and
-- plugins, then registers it. Sets the SCHEMA global.
-- On the server the list of disabled plugins is loaded first; a dependency of the schema
-- that is disabled is left out without stopping the schema from loading.
-- Runs the PreLoadPlugins, OnPluginsLoaded and OnSchemaLoaded hooks.
function Plugin.include_schema()
  local schema_info = Flux.get_schema_info()
  local schema_path = schema_info.folder
  local schema_folder = schema_path..'/schema'
  local file_path = 'gamemodes/'..schema_path..'/'..schema_path..'.yml'
  local deps = {}

  if SERVER then
    Plugin.load_disabled()
  end

  --- Called at the start of `Plugin.include_schema`, before the dependencies of the schema,
  -- the schema itself and its plugins are included.
  -- Runs on both the server and the client, on boot and again on every code refresh. The
  -- list of disabled plugins is known by then, see `Plugin.is_disabled`.
  hook.Run('PreLoadPlugins')

  if SERVER and file.Exists(file_path, 'GAME') then
    Flux.dev_print('Reading and loading schema dependencies from '..file_path)

    Flux.shared.schema_info.depends = {}

    local schema_yml = YAML.eval(File.read(file_path))
    deps = schema_yml.depends or {}

    if IS_DEVELOPMENT then
      table.map(schema_yml.depends_development or {}, function(v)
        table.insert(deps, v)
      end)
    end

    table.map(deps, function(v)
      if !v:find('sv_') then
        table.insert(Flux.shared.schema_info.depends, v)
      end
    end)
  elseif CLIENT then
    deps = Flux.shared.schema_info.depends
  end

  schema_depends = istable(deps) and deps or {}

  if istable(deps) then
    for k, v in ipairs(deps) do
      if !Plugin.require(v) and !is_unavailable(v) then
        long_error(
          "Unable to load the schema! Dependency missing: '"..
          tostring(v)..
          "'!\nPlease install this plugin in your schema's 'plugins' folder!\n"..
          'Alternatively please make sure that your server can download packages from the cloud!\n'
        )

        return
      end
    end
  end

  if SERVER then AddCSLuaFile(schema_path..'/gamemode/cl_init.lua') end

  SCHEMA = PluginInstance.new(schema_info.name, schema_info)
  SCHEMA._is_schema = true

  require_relative(schema_folder..'/sh_schema')

  Plugin.include_folders(schema_folder)
  Plugin.include_plugins(schema_path..'/plugins')

  --- Called once the schema's `sh_schema.lua`, its extra folders and all of its plugins have
  -- been included, right before the schema itself is registered.
  -- Runs on both the server and the client. Plugins commonly use it to run registration hooks
  -- of their own, since every plugin is able to answer them by now. On the first load the
  -- schema's functions are not in the hook cache yet at this point; the schema can use
  -- OnSchemaLoaded instead.
  hook.Run('OnPluginsLoaded')

  if schema_info.name and schema_info.author then
    MsgC(Color(255, 255, 0), schema_info.name)
    MsgC(Color(0, 255, 100), ' by '..schema_info.author..' has been loaded!\n')
  end

  SCHEMA:register()

  --- Called at the end of `Plugin.include_schema`, once all plugins have been loaded and the
  -- schema has been registered.
  -- Runs on both the server and the client.
  hook.Call('OnSchemaLoaded', GM)
end

do
  local tolerance = {
    '',
    '/plugin.yml',
    '.lua',
    '/plugin/sh_plugin.lua'
  }

  --- Makes sure that a plugin (or a package) is loaded, including it if it has not been yet.
  -- Plugins are looked up in the Flux, cloud and schema plugin folders.
  -- Please specify the full file name if requiring a single-file Plugin.
  -- @param name [String plugin or package name]
  -- @return [Boolean true if the dependency is loaded or could be found; false if it could
  --   not, if the plugin is disabled, or if it was left out because one of its own
  --   dependencies is disabled or missing]
  function Plugin.require(name)
    if !isstring(name) then return false end
    if CLIENT and is_unavailable(name) then return false end

    if CLIENT and Flux.shared.deps_info[name] then
      if Flux.shared.deps_info[name].server_only then
        return true
      end
    end

    if !Plugin.loaded(name) then
      local search_paths = {
        'flux/plugins/',
        '_flux/plugins/'..Flux.get_version()..'/',
        (Flux.get_schema_folder() or 'flux')..'/plugins/'
      }

      for k, v in ipairs(search_paths) do
        local should_include = !LITE_REFRESH or !v:include('flux')

        for _, ending in ipairs(tolerance) do
          if file.Exists(v..name..ending, 'LUA') then
            if should_include then
              Plugin.include(v..name)
            end

            return !is_unavailable(name)
          end
        end

        for _, prefix in pairs({ 'sv_', 'sh_', 'cl_' }) do
          if file.Exists(v..prefix..name..'.lua', 'LUA') then
            if should_include then
              Plugin.include(v..prefix..name..'.lua')
            end

            if prefix == 'sv_' then
              Flux.shared.deps_info[name] = {
                server_only = true
              }
            end

            return !is_unavailable(name)
          end
        end
      end
    else
      return true
    end

    if Package:included(name) then
      return true
    elseif Package:exists(name) then
      local success, err = pcall(Package.include, Package, name)

      if success then
        return true
      end
    end

    return false
  end
end

--- Includes all plugins inside a folder: single-file plugins first, then plugin folders.
-- @param folder [String folder relative to the LUA search path, without a trailing slash]
function Plugin.include_plugins(folder)
  local files, folders = file.Find(folder..'/*', 'LUA')

  for k, v in ipairs(files) do
    if File.ext(v) == 'lua' then
      Plugin.include(folder..'/'..v)
    end
  end

  for k, v in ipairs(folders) do
    Plugin.include(folder..'/'..v)
  end
end

do
  local ent_data = {
    weapons = {
      table = 'SWEP',
      func = weapons.Register,
      default_data = {
        Primary = {},
        Secondary = {},
        Base = 'weapon_base'
      }
    },
    entities = {
      table = 'ENT',
      func = scripted_ents.Register,
      default_data = {
        Type = 'anim',
        Base = 'base_gmodentity',
        Spawnable = true
      }
    },
    effects = {
      table = 'EFFECT',
      func = effects and effects.Register,
      clientside = true
    }
  }

  --- Includes and registers the scripted weapons, entities and effects found in a folder.
  -- Looks for 'weapons', 'entities' and 'effects' subfolders, each containing single .lua
  -- files or folders with shared.lua, init.lua and cl_init.lua.
  -- @param folder [String path of a plugin's 'entities' folder, without a trailing slash]
  function Plugin.include_entities(folder)
    local _, dirs = file.Find(folder..'/*', 'LUA')

    for k, v in ipairs(dirs) do
      if !ent_data[v] then continue end

      local dir = folder..'/'..v
      local data = ent_data[v]
      local files, folders = file.Find(dir..'/*', 'LUA')

      for k, v in ipairs(folders) do
        local path = dir..'/'..v
        local id = (File.name(path) or ''):gsub('%.lua$', ''):to_id()
        local register = false
        local var = data.table

        _G[var] = table.Copy(data.default_data)
        _G[var].ClassName = id

        if file.Exists(path..'/shared.lua', 'LUA') then
          require_relative(path..'/shared')

          register = true
        end

        if file.Exists(path..'/init.lua', 'LUA') then
          require_relative(path..'/init')

          register = true
        end

        if file.Exists(path..'/cl_init.lua', 'LUA') then
          require_relative(path..'/cl_init')

          register = true
        end

        if register then
          if data.clientside and !CLIENT then _G[var] = nil continue end

          data.func(_G[var], id)
        end

        _G[var] = nil
      end

      for k, v in ipairs(files) do
        local path = dir..'/'..v
        local id = (File.name(path) or ''):gsub('%.lua$', ''):to_id()
        local var = data.table

        _G[var] = table.Copy(data.default_data)
        _G[var].ClassName = id

        require_relative(path)

        if data.clientside and !CLIENT then _G[var] = nil continue end

        data.func(_G[var], id)

        _G[var] = nil
      end
    end
  end
end

--- Adds a folder to the list of extra folders that are included for every plugin.
-- @param extra [String folder name relative to the plugin's folder, e.g. 'items']
function Plugin.add_extra(extra)
  if !isstring(extra) then return end

  extras[#extras + 1] = extra
end

--- Includes all extra folders (lib, classes, config, entities, themes and so on) of a
-- plugin or schema. A plugin can take over a folder by returning a non-nil value from the
-- PluginIncludeFolder hook.
-- @param folder [String plugin or schema folder, without a trailing slash]
function Plugin.include_folders(folder)
  for k, v in ipairs(extras) do
    --- Called for every extra folder of a plugin or of the schema before Flux includes it: the
    -- default ones such as 'lib' or 'config' and those added with `Plugin.add_extra`.
    -- Lets a plugin load the folders it has added in its own way, as the items and factions
    -- plugins do. Runs on both the server and the client, whether the folder exists or not.
    -- @param extra [String name of the extra folder, relative to the plugin's folder]
    -- @param folder [String folder of the plugin or schema, without a trailing slash]
    -- @return [Boolean Return any value other than nil to take the folder over, so that Flux
    --   does not include it itself]
    if Plugin.call('PluginIncludeFolder', v, folder) == nil then
      if v == 'entities' then
        Plugin.include_entities(folder..'/'..v)
      elseif v == 'themes' then
        Pipeline.include_folder('theme', folder..'/themes/')
      elseif v == 'tools' then
        Pipeline.include_folder('tool', folder..'/tools/')
      elseif v == 'commands' then
        Pipeline.include_folder('commands', folder..'/commands/')
      elseif v == 'config' then
        if SERVER then
          local files, folders = file.Find('gamemodes/'..folder..'/config/*.yml', 'GAME')

          if files then
            local configs = {}

            for k, v in pairs(files) do
              table.Merge(configs, Config.read('gamemodes/'..folder..'/config/'..v))
            end

            Flux.shared.configs[folder] = configs
          end
        elseif Flux.shared.configs[folder] then
          Config.read(Flux.shared.configs[folder])
        end
      elseif SERVER then
        if v == 'languages' then
          Pipeline.include_folder('language', folder..'/languages/')
        elseif v == 'migrations' then
          Pipeline.include_folder('migrations', folder..'/migrations/')
        elseif v == 'views/lumen' then
          Pipeline.include_folder('lumen', folder..'/'..v)
        else
          require_relative_folder(folder..'/'..v)
        end
      else
        require_relative_folder(folder..'/'..v)
      end
    end
  end
end

do
  local old_hook_call = Plugin.old_hook_call or hook.Call
  Plugin.old_hook_call = old_hook_call

  -- If we're running in development, we should be using pcall'ed hook.Call rather than the unsafe one.
  if Flux.development then
    --- Overrides hook.Call so that plugin and schema hooks from the hook cache are called
    -- before the regular hooks. Development variant: handlers are run with pcall, failures
    -- are printed and reported through the OnHookError hook.
    -- @param name [String hook name]
    -- @param gm [Map gamemode table, or nil to skip gamemode hooks]
    -- @param ... [Vararg arguments to pass to the handlers]
    -- @return [Any values returned by the first handler that returned non-nil (cached plugin
    --   hooks pass on six values at most)]
    function hook.Call(name, gm, ...)
      local handlers = hooks_cache[name]

      if handlers then
        for k, v in ipairs(handlers) do
          local success, a, b, c, d, e, f = pcall(v[1], v[2], ...)

          if !success then
            ErrorNoHalt('[Flux - '..(v.id or v[2]:get_name())..'] The '..name..' hook has failed to run!\n')
            error_with_traceback(tostring(a))

            if name != 'OnHookError' then
              --- Called when a handler from the hook cache (a plugin's, the schema's or one
              -- added with `Plugin.add_hooks`) throws an error.
              -- Only runs outside of the production environment, where these handlers are
              -- called through pcall. An error inside of an OnHookError handler does not run
              -- the hook again.
              -- @param name [String name of the hook whose handler has failed]
              -- @param entry [Map hook cache entry: the handler at index 1, the table it
              --   belongs to at index 2 and the ID given to `Plugin.add_hooks` in the `id`
              --   field]
              hook.Call('OnHookError', gm, name, v)
            end
          elseif a != nil then
            return a, b, c, d, e, f
          end
        end
      end

      return old_hook_call(name, gm, ...)
    end
  else
    -- While generally a bad idea, the pcall-less method is faster and if you're not developing
    -- chances are low that you'll ever run into an error anyway.

    --- Overrides hook.Call so that plugin and schema hooks from the hook cache are called
    -- before the regular hooks. Production variant: handlers are called without pcall.
    -- @param name [String hook name]
    -- @param gm [Map gamemode table, or nil to skip gamemode hooks]
    -- @param ... [Vararg arguments to pass to the handlers]
    -- @return [Any values returned by the first handler that returned non-nil (cached plugin
    --   hooks pass on six values at most)]
    function hook.Call(name, gm, ...)
      local handlers = hooks_cache[name]

      if handlers then
        for k, v in ipairs(handlers) do
          local a, b, c, d, e, f = v[1](v[2], ...)

          if a != nil then
            return a, b, c, d, e, f
          end
        end
      end

      return old_hook_call(name, gm, ...)
    end
  end

  --- Calls a hook and returns what its handlers returned.
  -- This function DOES NOT call GM: (gamemode) hooks!
  -- It only calls plugin, schema and hook.Add'ed hooks!
  -- @param name [String hook name]
  -- @param ... [Vararg arguments to pass to the handlers]
  -- @return [Any values returned by the first handler that returned non-nil]
  function Plugin.call(name, ...)
    return hook.Call(name, nil, ...)
  end
end
