if Plugin then return end

require_relative 'plugin_instance'

mod 'Plugin'

local stored = {}
local unloaded = {}
local hooks_cache = {}
local reload_data = {}
local load_cache = {}
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
  'views', 'views/html',
  'views/assets/stylesheets',
  'views/assets/javascripts',
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
      hooks_cache[k] = hooks_cache[k] or {}
      table.insert(hooks_cache[k], { v, obj, id = id })
    end
  end
end

--- Registers the functions of a table as hook handlers.
-- ```
-- local hooks = {}
--
-- function hooks:PlayerButtonDown(player, key)
--   Cable.send(player, 'fl_bind_pressed', key)
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

--- Checks whether a plugin is on the list of disabled plugins.
-- @param folder [String plugin folder]
-- @return [Boolean truthy if the plugin is disabled; nil if it is not, or if the list has
--   not been loaded]
function Plugin.is_disabled(folder)
  if Flux.shared.disabled_plugins then
    return Flux.shared.disabled_plugins[folder]
  end
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

  if obj.should_refresh == false then
    reload_data[obj:get_path()] = false
  else
    reload_data[obj:get_path()] = true
  end

  if SERVER then
    if SCHEMA == obj then
      local folder_name = obj.folder:trim_end('/schema')
      local file_path = 'gamemodes/'..folder_name..'/'..folder_name..'.yml'

      if file.Exists(file_path, 'GAME') then
        Flux.dev_print('Importing config: '..file_path)

        Config.import(File.read(file_path), CONFIG_PLUGIN)
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
-- @param path [String plugin folder or .lua file, relative to the LUA search path]
-- @return [Map plugin info, or nil if the plugin was not loaded (already loaded, wrong
--   environment or missing dependency)]
function Plugin.include(path)
  local id = File.name(path)
  local ext = File.ext(id)
  local data = {}
  data.id = id
  data.path = path
  data.folder = path
  data.single_file = ext == 'lua'

  if reload_data[folder] == false then
    Flux.dev_print('Not reloading plugin: '..path)
    return
  elseif Plugin.loaded(id) then
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
      return
    elseif istable(data.environment) and !table.HasValue(data.environment, ENV['FLUX_ENV']) then
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
        ErrorNoHalt("Not loading the '"..tostring(path).."' plugin! Dependency missing: '"..tostring(v).."'!\n")
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
-- Runs the PreLoadPlugins, OnPluginsLoaded and OnSchemaLoaded hooks.
function Plugin.include_schema()
  local schema_info = Flux.get_schema_info()
  local schema_path = schema_info.folder
  local schema_folder = schema_path..'/schema'
  local file_path = 'gamemodes/'..schema_path..'/'..schema_path..'.yml'
  local deps = {}

  hook.run('PreLoadPlugins')

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

  if istable(deps) then
    for k, v in ipairs(deps) do
      if !Plugin.require(v) then
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

  hook.run('OnPluginsLoaded')

  if schema_info.name and schema_info.author then
    MsgC(Color(255, 255, 0), schema_info.name)
    MsgC(Color(0, 255, 100), ' by '..schema_info.author..' has been loaded!\n')
  end

  SCHEMA:register()

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
  -- @return [Boolean true if the dependency is loaded or could be found, false otherwise]
  function Plugin.require(name)
    if !isstring(name) then return false end

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

            return true
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

            return true
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

  table.insert(extras, extra)
end

--- Includes all extra folders (lib, classes, config, entities, themes and so on) of a
-- plugin or schema. A plugin can take over a folder by returning a non-nil value from the
-- PluginIncludeFolder hook.
-- @param folder [String plugin or schema folder, without a trailing slash]
function Plugin.include_folders(folder)
  for k, v in ipairs(extras) do
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
        elseif v:find('assets') or v:find('html') then
          Pipeline.include_folder('html', folder..'/'..v)
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
      if hooks_cache[name] then
        for k, v in ipairs(hooks_cache[name]) do
          local success, a, b, c, d, e, f = pcall(v[1], v[2], ...)

          if !success then
            ErrorNoHalt('[Flux - '..(v.id or v[2]:get_name())..'] The '..name..' hook has failed to run!\n')
            error_with_traceback(tostring(a))

            if name != 'OnHookError' then
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
      if hooks_cache[name] then
        for k, v in ipairs(hooks_cache[name]) do
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

  hook.run = hook.Run
  hook.call = hook.Call
end
