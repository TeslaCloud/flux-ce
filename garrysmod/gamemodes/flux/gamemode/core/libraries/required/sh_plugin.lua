--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

if (plugin) then return end

library.New "plugin"

local stored = {}
local unloaded = {}
local hooks_cache = {}
local reload_data = {}
local load_cache = {}
local default_extras = {
  "libraries",
  "libraries/meta",
  "libraries/classes",
  "libs",
  "libs/meta",
  "libs/classes",
  "classes",
  "meta",
  "config",
  "languages",
  "ui/controllers",
  "ui/view",
  "tools",
  "themes",
  "entities"
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

class "Plugin"

function Plugin:Plugin(id, data)
  self.name = data.name or "Unknown Plugin"
  self.author = data.author or "Unknown Author"
  self.folder = data.folder or name:MakeID()
  self.description = data.description or "This plugin has no description."
  self.id = id or data.id or name:MakeID() or "unknown"

  table.Merge(self, data)
end

function Plugin:GetName()
  return self.name
end

function Plugin:GetFolder()
  return self.folder
end

function Plugin:GetAuthor()
  return self.author
end

function Plugin:GetDescription()
  return self.description
end

function Plugin:SetName(name)
  self.name = name or self.name or "Unknown Plugin"
end

function Plugin:SetAuthor(author)
  self.author = author or self.author or "Unknown"
end

function Plugin:SetDescription(desc)
  self.description = desc or self.description or "No description provided!"
end

function Plugin:SetData(data)
  table.Merge(self, data)
end

function Plugin:SetAlias(alias)
  if (isstring(alias)) then
    _G[alias] = self
    self.alias = alias
  end
end

function Plugin:__tostring()
  return "Plugin ["..self.name.."]"
end

function Plugin:Register()
  plugin.register(self)
end

Plugin = Plugin

function plugin.cache_functions(obj, id)
  for k, v in pairs(obj) do
    if (isfunction(v)) then
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
      if (v2.id and v2.id == id) then
        hooks_cache[k][k2] = nil
      end
    end
  end
end

function plugin.find(id)
  if (stored[id]) then
    return stored[id], id
  else
    for k, v in pairs(stored) do
      if (v.id == id or v:GetFolder() == id or v:GetName() == id) then
        return v, k
      end
    end
  end
end

-- A function to unhook a plugin from cache.
function plugin.remove_from_cache(id)
  local pluginTable = plugin.find(id) or (istable(id) and id)

  -- Awful lot of if's and end's.
  if (pluginTable) then
    if (pluginTable.OnUnhook) then
      try {
        pluginTable.OnUnhook, pluginTable
      } catch {
        function(exception)
          ErrorNoHalt("[Flux:Plugin] OnUnhook method has failed to run! "..tostring(pluginTable).."\n"..tostring(exception).."\n")
        end
      }
    end

    for k, v in pairs(pluginTable) do
      if (isfunction(v) and hooks_cache[k]) then
        for index, tab in ipairs(hooks_cache[k]) do
          if (tab[2] == pluginTable) then
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
  local pluginTable = plugin.find(id)

  if (pluginTable) then
    if (pluginTable.OnRecache) then
      try {
        pluginTable.OnRecache, pluginTable
      } catch {
        function(exception)
          ErrorNoHalt("[Flux:Plugin] OnRecache method has failed to run! "..tostring(pluginTable).."\n"..tostring(exception).."\n")
        end
      }
    end

    plugin.cache_functions(pluginTable)
  end
end

-- A function to remove the plugin entirely.
function plugin.remove(id)
  local pluginTable, pluginID = plugin.find(id)

  if (pluginTable) then
    if (pluginTable.OnRemoved) then
      try {
        pluginTable.OnRemoved, pluginTable
      } catch {
        function(exception)
          ErrorNoHalt("[Flux:Plugin] OnRemoved method has failed to run! "..tostring(pluginTable).."\n"..tostring(exception).."\n")
        end
      }
    end

    plugin.remove_from_cache(id)

    stored[pluginID] = nil
  end
end

function plugin.is_disabled(folder)
  if (fl.sharedTable.disabledPlugins) then
    return fl.sharedTable.disabledPlugins[folder]
  end
end

function plugin.loaded(obj)
  if (istable(obj)) then
    return load_cache[obj.id]
  elseif (isstring(obj)) then
    return load_cache[obj]
  end

  return false
end

function plugin.register(obj)
  plugin.cache_functions(obj)

  if (obj.ShouldRefresh == false) then
    reload_data[obj:GetFolder()] = false
  else
    reload_data[obj:GetFolder()] = true
  end

  if (SERVER) then
    if (Schema == obj) then
      local folderName = obj.folder:RemoveTextFromEnd("/schema")
      local filePath = "gamemodes/"..folderName.."/"..folderName..".cfg"

      if (file.Exists(filePath, "GAME")) then
        fl.DevPrint("Importing config: "..filePath)

        config.Import(fileio.Read(filePath), CONFIG_PLUGIN)
      end
    end
  end

  if (isfunction(obj.OnPluginLoaded)) then
    obj.OnPluginLoaded(obj)
  end

  stored[obj:GetFolder()] = obj
  load_cache[obj.id] = true
end

function plugin.include(folder)
  local hasMainFile = false
  local id = folder:GetFileFromFilename()
  local ext = id:GetExtensionFromFilename()
  local data = {}
  data.folder = folder
  data.id = id
  data.pluginFolder = folder

  if (reload_data[folder] == false) then
    fl.DevPrint("Not reloading plugin: "..folder)

    return
  elseif (plugin.loaded(id)) then
    return
  end

  fl.DevPrint("Loading plugin: "..folder)

  if (ext != "lua") then
    if (SERVER) then
      if (file.Exists(folder.."/plugin.cfg", "LUA")) then
        local configData = config.ConfigToTable(file.Read(folder.."/plugin.cfg", "LUA"))
        local dataTable = {name = configData.name, description = configData.description, author = configData.author, depends = configData.depends}
          dataTable.pluginFolder = folder.."/plugin"
          dataTable.pluginMain = "sh_plugin.lua"

          if (file.Exists(dataTable.pluginFolder.."/sh_"..(dataTable.name or id)..".lua", "LUA")) then
            dataTable.pluginMain = "sh_"..(dataTable.name or id)..".lua"
          end
        table.Merge(data, dataTable)

        configData.name, configData.description, configData.author, configData.depends = nil, nil, nil, nil

        for k, v in pairs(configData) do
          if (v != nil) then
            config.Set(k, v)
          end
        end

        fl.sharedTable.pluginInfo[folder] = data
      end
    else
      table.Merge(data, fl.sharedTable.pluginInfo[folder])
    end
  end

  if (istable(data.depends)) then
    for k, v in ipairs(data.depends) do
      if (!plugin.require(v)) then
        ErrorNoHalt("[Flux] Not loading the '"..tostring(folder).."' plugin! Dependency missing: '"..tostring(v).."'!\n")

        return
      end
    end
  end

  PLUGIN = Plugin(id, data)

  if (stored[folder]) then
    PLUGIN = stored[folder]
  end

  if (ext != "lua") then
    util.Include(data.pluginFolder.."/"..data.pluginMain)
  else
    if (file.Exists(folder, "LUA")) then
      util.Include(folder)
    end
  end

  plugin.include_folders(data.pluginFolder)

  PLUGIN:Register()
  PLUGIN = nil

  return data
end

function plugin.include_schema()
  local schemaInfo = fl.GetSchemaInfo()
  local schemaPath = schemaInfo.folder
  local schemaFolder = schemaPath.."/schema"
  local filePath = "gamemodes/"..schemaPath.."/"..schemaPath..".cfg"

  if (file.Exists(filePath, "GAME")) then
    fl.DevPrint("Checking schema dependencies using "..filePath)

    local dependencies = config.ConfigToTable(fileio.Read(filePath)).depends

    if (istable(dependencies)) then
      for k, v in ipairs(dependencies) do
        if (!plugin.require(v)) then
          ErrorNoHalt("[Flux] Unable to load schema! Dependency missing: '"..tostring(v).."'!\n")
          ErrorNoHalt("Please install this plugin in your schema's 'plugins' folder!\n")

          return
        end
      end
    end
  end

  if (SERVER) then AddCSLuaFile(schemaPath.."/gamemode/cl_init.lua") end

  Schema = Plugin(schemaInfo.name, schemaInfo)

  util.Include(schemaFolder.."/sh_schema.lua")

  plugin.include_folders(schemaFolder)
  plugin.include_plugins(schemaPath.."/plugins")

  if (schemaInfo.name and schemaInfo.author) then
    MsgC(Color(0, 255, 100, 255), "[Flux] ")
    MsgC(Color(255, 255, 0), schemaInfo.name)
    MsgC(Color(0, 255, 100), " by "..schemaInfo.author.." has been loaded!\n")
  end

  Schema:Register()

  hook.Run("OnSchemaLoaded")
end

-- Please specify full file name if requiring a single-file plugin.
function plugin.require(pluginName)
  if (!isstring(pluginName)) then return false end

  if (!plugin.loaded(pluginName)) then
    local searchPaths = {
      "flux/plugins/",
      (fl.GetSchemaFolder() or "flux").."/plugins/"
    }

    local tolerance = {
      "",
      "/plugin.cfg",
      ".lua",
      "/plugin/sh_plugin.lua"
    }

    for k, v in ipairs(searchPaths) do
      for _, ending in ipairs(tolerance) do
        if (file.Exists(v..pluginName..ending, "LUA")) then
          plugin.include(v..pluginName)

          return true
        end
      end
    end
  else
    return true
  end

  return false
end

function plugin.include_plugins(folder)
  local files, folders = file.Find(folder.."/*", "LUA")

  for k, v in ipairs(files) do
    if (v:GetExtensionFromFilename() == "lua") then
      plugin.include(folder.."/"..v)
    end
  end

  for k, v in ipairs(folders) do
    plugin.include(folder.."/"..v)
  end
end

do
  local entData = {
    weapons = {
      table = "SWEP",
      func = weapons.Register,
      defaultData = {
        Primary = {},
        Secondary = {},
        Base = "weapon_base"
      }
    },
    entities = {
      table = "ENT",
      func = scripted_ents.Register,
      defaultData = {
        Type = "anim",
        Base = "base_gmodentity",
        Spawnable = true
      }
    },
    effects = {
      table = "EFFECT",
      func = effects and effects.Register,
      clientside = true
    }
  }

  function plugin.include_entities(folder)
    local _, dirs = file.Find(folder.."/*", "LUA")

    for k, v in ipairs(dirs) do
      if (!entData[v]) then continue end

      local dir = folder.."/"..v
      local data = entData[v]
      local files, folders = file.Find(dir.."/*", "LUA")

      for k, v in ipairs(folders) do
        local path = dir.."/"..v
        local uniqueID = (string.GetFileFromFilename(path) or ""):Replace(".lua", ""):MakeID()
        local register = false
        local var = data.table

        _G[var] = table.Copy(data.defaultData)
        _G[var].ClassName = uniqueID

        if (file.Exists(path.."/shared.lua", "LUA")) then
          util.Include(path.."/shared.lua")

          register = true
        end

        if (file.Exists(path.."/init.lua", "LUA")) then
          util.Include(path.."/init.lua")

          register = true
        end

        if (file.Exists(path.."/cl_init.lua", "LUA")) then
          util.Include(path.."/cl_init.lua")

          register = true
        end

        if (register) then
          if (data.clientside and !CLIENT) then _G[var] = nil continue end

          data.func(_G[var], uniqueID)
        end

        _G[var] = nil
      end

      for k, v in ipairs(files) do
        local path = dir.."/"..v
        local uniqueID = (string.GetFileFromFilename(path) or ""):Replace(".lua", ""):MakeID()
        local var = data.table

        _G[var] = table.Copy(data.defaultData)
        _G[var].ClassName = uniqueID

        util.Include(path)

        if (data.clientside and !CLIENT) then _G[var] = nil continue end

        data.func(_G[var], uniqueID)

        _G[var] = nil
      end
    end
  end
end

function plugin.add_extra(strExtra)
  if (!isstring(strExtra)) then return end

  table.insert(extras, strExtra)
end

function plugin.include_folders(folder)
  for k, v in ipairs(extras) do
    if (plugin.call("PluginIncludeFolder", v, folder) == nil) then
      if (v == "entities") then
        plugin.include_entities(folder.."/"..v)
      elseif (v == "themes") then
        pipeline.IncludeDirectory("theme", folder.."/themes/")
      elseif (v == "tools") then
        pipeline.IncludeDirectory("tool", folder.."/tools/")
      else
        util.IncludeDirectory(folder.."/"..v)
      end
    end
  end
end

do
  local oldHookCall = plugin.OldHookCall or hook.Call
  plugin.OldHookCall = oldHookCall

  -- If we're running the developer's mode, we should be using pcall'ed hook.Call rather than unsafe one.
  if (fl.Devmode) then
    function hook.Call(name, gm, ...)
      if (hooks_cache[name]) then
        for k, v in ipairs(hooks_cache[name]) do
          local success, a, b, c, d, e, f = pcall(v[1], v[2], ...)

          if (!success) then
            ErrorNoHalt("[Flux:"..(v.id or v[2]:GetName()).."] The "..name.." hook has failed to run!\n")
            ErrorNoHalt(tostring(a), "\n")

            if (name != "OnHookError") then
              hook.Call("OnHookError", gm, name, v)
            end
          elseif (a != nil) then
            return a, b, c, d, e, f
          end
        end
      end

      return oldHookCall(name, gm, ...)
    end
  else
    -- While generally a bad idea, pcall-less method is faster and if you're not developing
    -- changes are low that you'll ever run into an error anyway.
    function hook.Call(name, gm, ...)
      if (hooks_cache[name]) then
        for k, v in ipairs(hooks_cache[name]) do
          local a, b, c, d, e, f = v[1](v[2], ...)

          if (a != nil) then
            return a, b, c, d, e, f
          end
        end
      end

      return oldHookCall(name, gm, ...)
    end
  end

  -- This function DOES NOT call GM: (gamemode) hooks!
  -- It only calls plugin, schema and hook.Add'ed hooks!
  function plugin.call(name, ...)
    return hook.Call(name, nil, ...)
  end
end
