if plugin then return end

library 'plugin'

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

function plugin.all()
  return stored
end

function plugin.get_cache()
  return hooks_cache
end

function plugin.clear_cache()
  plugin.clear_extras()

  hooks_cache = {}
  load_cache = {}
end

function plugin.clear_load_cache()
  load_cache = {}
end

function plugin.clear_extras()
  extras = table.Copy(default_extras)
end

class 'Plugin'

function Plugin:init(id, data)
  self.name = data.name or 'Unknown Plugin'
  self.author = data.author or 'Unknown Author'
  self.folder = data.folder or name:to_id()
  self.path = data.path or self.folder
  self.description = data.description or 'This plugin has no description.'
  self.id = id or data.id or name:to_id() or 'unknown'

  table.safe_merge(self, data)
end

function Plugin:get_name()
  return self.name
end

function Plugin:get_folder()
  return self.folder
end

function Plugin:get_path()
  return self.path
end

function Plugin:get_author()
  return self.author
end

function Plugin:get_description()
  return self.description
end

function Plugin:set_name(name)
  self.name = name or self.name or 'Unknown Plugin'
end

function Plugin:set_author(author)
  self.author = author or self.author or 'Unknown'
end

function Plugin:set_description(desc)
  self.description = desc or self.description or 'No description provided!'
end

function Plugin:set_data(data)
  table.safe_merge(self, data)
end

function Plugin:set_global(alias)
  if isstring(alias) then
    _G[alias] = self
    self.alias = alias
  end
end

function Plugin:is_schema()
  return self._is_schema
end

function Plugin:__tostring()
  return 'Plugin ['..self.name..']'
end

function Plugin:register()
  plugin.register(self)
end

Plugin = Plugin

function plugin.cache_functions(obj, id)
  for k, v in pairs(obj) do
    if isfunction(v) then
      hooks_cache[k] = hooks_cache[k] or {}
      table.insert(hooks_cache[k], {v, obj, id = id})
    end
  end
end

function plugin.add_hooks(id, obj)
  plugin.cache_functions(obj, id)
end

function plugin.remove_hooks(id)
  for k, v in pairs(hooks_cache) do
    for k2, v2 in ipairs(v) do
      if v2.id and v2.id == id then
        hooks_cache[k][k2] = nil
      end
    end
  end
end

function plugin.find(id)
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

-- A function to unhook a plugin from cache.
function plugin.remove_from_cache(id)
  local plugin_table = plugin.find(id) or (istable(id) and id)

  -- Awful lot of if's and end's.
  if plugin_table then
    if plugin_table.OnUnhook then
      try {
        plugin_table.OnUnhook, plugin_table
      } catch {
        function(exception)
          ErrorNoHalt('OnUnhook method has failed to run! '..tostring(plugin_table)..'\n'..tostring(exception)..'\n')
        end
      }
    end

    for k, v in pairs(plugin_table) do
      if isfunction(v) and hooks_cache[k] then
        for index, tab in ipairs(hooks_cache[k]) do
          if tab[2] == plugin_table then
            table.remove(hooks_cache[k], index)

            break
          end
        end
      end
    end
  end
end

-- A function to cache existing plugin's hooks.
function plugin.recache(id)
  local plugin_table = plugin.find(id)

  if plugin_table then
    if plugin_table.OnRecache then
      try {
        plugin_table.OnRecache, plugin_table
      } catch {
        function(exception)
          ErrorNoHalt('OnRecache method has failed to run! '..tostring(plugin_table)..'\n'..tostring(exception)..'\n')
        end
      }
    end

    plugin.cache_functions(plugin_table)
  end
end

-- A function to remove the plugin entirely.
function plugin.remove(id)
  local plugin_table, plugin_id = plugin.find(id)

  if plugin_table then
    if plugin_table.OnRemoved then
      try {
        plugin_table.OnRemoved, plugin_table
      } catch {
        function(exception)
          ErrorNoHalt('OnRemoved method has failed to run! '..tostring(plugin_table)..'\n'..tostring(exception)..'\n')
        end
      }
    end

    plugin.remove_from_cache(id)

    stored[plugin_id] = nil
  end
end

function plugin.is_disabled(folder)
  if Flux.shared.disabled_plugins then
    return Flux.shared.disabled_plugins[folder]
  end
end

function plugin.loaded(obj)
  if istable(obj) then
    return load_cache[obj.id]
  elseif isstring(obj) then
    return load_cache[obj]
  end

  return false
end

function plugin.register(obj)
  plugin.cache_functions(obj)

  if obj.should_refresh == false then
    reload_data[obj:get_path()] = false
  else
    reload_data[obj:get_path()] = true
  end

  if SERVER then
    if Schema == obj then
      local folder_name = obj.folder:trim_end('/schema')
      local file_path = 'gamemodes/'..folder_name..'/'..folder_name..'.yml'

      if file.Exists(file_path, 'GAME') then
        Flux.dev_print('Importing config: '..file_path)

        Config.import(fileio.Read(file_path), CONFIG_PLUGIN)
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

function plugin.include(path)
  local id = path:GetFileFromFilename()
  local ext = id:GetExtensionFromFilename()
  local data = {}
  data.id = id
  data.path = path
  data.folder = path
  data.single_file = ext == 'lua'

  if reload_data[folder] == false then
    Flux.dev_print('Not reloading plugin: '..path)
    return
  elseif plugin.loaded(id) then
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
    if isstring(data.environment) and FLUX_ENV != data.environment then
      return
    elseif istable(data.environment) and !table.HasValue(data.environment, FLUX_ENV) then
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
      if !plugin.require(v) then
        ErrorNoHalt("Not loading the '"..tostring(path).."' plugin! Dependency missing: '"..tostring(v).."'!\n")
        return
      end
    end
  end

  PLUGIN = Plugin.new(id, data)

  if stored[path] then
    PLUGIN = stored[path]
  end

  plugin.include_folders(data.folder)

  if !data.single_file then
    util.include(data.folder..'/'..data.plugin_main)
  else
    if file.Exists(path, 'LUA') then
      util.include(path)
    end
  end

  PLUGIN:register()
  PLUGIN = nil

  return data
end

function plugin.include_schema()
  local schema_info = Flux.get_schema_info()
  local schema_path = schema_info.folder
  local schema_folder = schema_path..'/schema'
  local file_path = 'gamemodes/'..schema_path..'/'..schema_path..'.yml'
  local deps = {}

  hook.run('PreLoadPlugins')

  if SERVER and file.Exists(file_path, 'GAME') then
    Flux.dev_print('Reading and loading schema dependencies from '..file_path)

    Flux.shared.schema_info.depends = {}

    local schema_yml = YAML.eval(fileio.Read(file_path))
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
      if !plugin.require(v) then
        ErrorNoHalt("Unable to load schema! Dependency missing: '"..tostring(v).."'!\n")
        ErrorNoHalt("Please install this plugin in your schema's 'plugins' folder!\n")
        ErrorNoHalt("Alternatively please make sure that your server can download packages from the cloud!\n")

        return
      end
    end
  end

  if SERVER then AddCSLuaFile(schema_path..'/gamemode/cl_init.lua') end

  Schema = Plugin.new(schema_info.name, schema_info)
  Schema._is_schema = true

  util.include(schema_folder..'/sh_schema.lua')

  plugin.include_folders(schema_folder)
  plugin.include_plugins(schema_path..'/plugins')

  hook.run('OnPluginsLoaded')

  if schema_info.name and schema_info.author then
    MsgC(Color(255, 255, 0), schema_info.name)
    MsgC(Color(0, 255, 100), ' by '..schema_info.author..' has been loaded!\n')
  end

  Schema:register()

  hook.Call('OnSchemaLoaded', GM)
end

do
  local tolerance = {
    '', '.', '..',
    '/plugin.yml',
    '.lua',
    '/plugin/sh_plugin.lua'
  }

  -- Please specify full file name if requiring a single-file plugin.
  function plugin.require(name)
    if !isstring(name) then return false end

    if !plugin.loaded(name) then
      local search_paths = {
        'flux/plugins/',
        (Flux.get_schema_folder() or 'flux')..'/plugins/'
      }

      for k, v in ipairs(search_paths) do
        if !v:find('flux') or !LITE_REFRESH then
          for _, ending in ipairs(tolerance) do
            if file.Exists(v..name..ending, 'LUA') then
              plugin.include(v..name)

              return true
            end
          end
        end
      end
    else
      return true
    end

    if Crate:included(name) then
      return true
    elseif Crate:exists(name) then
      local success, err = pcall(Crate.include, Crate, name)

      if success then
        return true
      end
    end

    return false
  end
end

function plugin.include_plugins(folder)
  local files, folders = file.Find(folder..'/*', 'LUA')

  for k, v in ipairs(files) do
    if v:GetExtensionFromFilename() == 'lua' then
      plugin.include(folder..'/'..v)
    end
  end

  for k, v in ipairs(folders) do
    plugin.include(folder..'/'..v)
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

  function plugin.include_entities(folder)
    local _, dirs = file.Find(folder..'/*', 'LUA')

    for k, v in ipairs(dirs) do
      if !ent_data[v] then continue end

      local dir = folder..'/'..v
      local data = ent_data[v]
      local files, folders = file.Find(dir..'/*', 'LUA')

      for k, v in ipairs(folders) do
        local path = dir..'/'..v
        local id = (string.GetFileFromFilename(path) or ''):Replace('.lua', ''):to_id()
        local register = false
        local var = data.table

        _G[var] = table.Copy(data.default_data)
        _G[var].ClassName = id

        if file.Exists(path..'/shared.lua', 'LUA') then
          util.include(path..'/shared.lua')

          register = true
        end

        if file.Exists(path..'/init.lua', 'LUA') then
          util.include(path..'/init.lua')

          register = true
        end

        if file.Exists(path..'/cl_init.lua', 'LUA') then
          util.include(path..'/cl_init.lua')

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
        local id = (string.GetFileFromFilename(path) or ''):Replace('.lua', ''):to_id()
        local var = data.table

        _G[var] = table.Copy(data.default_data)
        _G[var].ClassName = id

        util.include(path)

        if data.clientside and !CLIENT then _G[var] = nil continue end

        data.func(_G[var], id)

        _G[var] = nil
      end
    end
  end
end

function plugin.add_extra(extra)
  if !isstring(extra) then return end

  table.insert(extras, extra)
end

function plugin.include_folders(folder)
  for k, v in ipairs(extras) do
    if plugin.call('PluginIncludeFolder', v, folder) == nil then
      if v == 'entities' then
        plugin.include_entities(folder..'/'..v)
      elseif v == 'themes' then
        Pipeline.include_folder('Theme', folder..'/themes/')
      elseif v == 'tools' then
        Pipeline.include_folder('tool', folder..'/tools/')
      elseif SERVER then
        if v == 'languages' then
          Pipeline.include_folder('language', folder..'/languages/')
        elseif v == 'migrations' then
          Pipeline.include_folder('migrations', folder..'/migrations/')
        elseif v:find('/assets/') or v:find('/html/') then
          Pipeline.include_folder('html', folder..'/'..v)
        else
          util.include_folder(folder..'/'..v)
        end
      else
        util.include_folder(folder..'/'..v)
      end
    end
  end
end

do
  local old_hook_call = plugin.old_hook_call or hook.Call
  plugin.old_hook_call = old_hook_call

  -- If we're running in development, we should be using pcall'ed hook.Call rather than unsafe one.
  if Flux.development then
    function hook.Call(name, gm, ...)
      if hooks_cache[name] then
        for k, v in ipairs(hooks_cache[name]) do
          local success, a, b, c, d, e, f = pcall(v[1], v[2], ...)

          if !success then
            ErrorNoHalt('[Flux - '..(v.id or v[2]:get_name())..'] The '..name..' hook has failed to run!\n')
            ErrorNoHalt(tostring(a), '\n')

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
    -- While generally a bad idea, pcall-less method is faster and if you're not developing
    -- changes are low that you'll ever run into an error anyway.
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

  -- This function DOES NOT call GM: (gamemode) hooks!
  -- It only calls plugin, schema and hook.Add'ed hooks!
  function plugin.call(name, ...)
    return hook.Call(name, nil, ...)
  end

  hook.run = hook.Run
  hook.call = hook.Call
end
