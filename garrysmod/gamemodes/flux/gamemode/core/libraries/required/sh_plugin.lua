--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (plugin) then return end

library.New "plugin"

local stored = {}
local hooksCache = {}
local reloadData = {}
local loadCache = {}
local extras = {
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
	"items",
	"derma",
	"tools",
	"themes"
}

function plugin.GetStored()
	return stored
end

function plugin.GetCache()
	return hooksCache
end

function plugin.ClearCache()
	hooksCache = {}
	loadCache = {}
end

function plugin.ClearLoadCache()
	loadCache = {}
end

class "CPlugin"

function CPlugin:CPlugin(id, data)
	self.m_Name = data.name or "Unknown Plugin"
	self.m_Author = data.author or "Unknown Author"
	self.m_Folder = data.folder or name:gsub(" ", "_"):lower()
	self.m_Description = data.description or "An undescribed plugin or schema."
	self.m_UniqueID = id or data.id or name:MakeID() or "unknown"

	table.Merge(self, data)
end

function CPlugin:GetName()
	return self.m_Name
end

function CPlugin:GetFolder()
	return self.m_Folder
end

function CPlugin:GetAuthor()
	return self.m_Author
end

function CPlugin:GetDescription()
	return self.m_Description
end

function CPlugin:SetName(name)
	self.m_Name = name or self.m_Name or "Unknown Plugin"
end

function CPlugin:SetAuthor(author)
	self.m_Author = author or self.m_Author or "Unknown"
end

function CPlugin:SetDescription(desc)
	self.m_Description = desc or self.m_Description or "No description provided!"
end

function CPlugin:SetData(data)
	table.Merge(self, data)
end

function CPlugin:SetAlias(alias)
	if (isstring(alias)) then
		_G[alias] = self
		self.alias = alias
	end
end

function CPlugin:__tostring()
	return "Plugin ["..self.m_Name.."]"
end

function CPlugin:Register()
	plugin.Register(self)
end

Plugin = CPlugin

function plugin.CacheFunctions(obj, id)
	for k, v in pairs(obj) do
		if (isfunction(v)) then
			hooksCache[k] = hooksCache[k] or {}
			table.insert(hooksCache[k], {v, obj, id = id})
		end
	end
end

function plugin.AddHooks(id, obj)
	plugin.CacheFunctions(obj, id)
end

function plugin.RemoveHooks(id)
	for k, v in pairs(hooksCache) do
		for k2, v2 in ipairs(v) do
			if (v2.id and v2.id == id) then
				hooksCache[k][k2] = nil
			end
		end
	end
end

function plugin.Register(obj)
	plugin.CacheFunctions(obj)

	if (obj.ShouldRefresh == false) then
		reloadData[obj:GetFolder()] = false
	else
		reloadData[obj:GetFolder()] = true
	end

	if (SERVER) then
		local filePath = "gamemodes/"..obj.folder.."/plugin.cfg"

		if (Schema == obj) then
			local folderName = obj.folder:RemoveTextFromEnd("/schema")

			filePath = "gamemodes/"..folderName.."/"..folderName..".cfg"
		end

		if (file.Exists(filePath, "GAME")) then
			local fileContents = fileio.Read(filePath)

			fl.DevPrint("Importing config: "..filePath)

			config.Import(fileContents, CONFIG_PLUGIN)
		end
	end

	if (isfunction(obj.OnPluginLoaded)) then
		obj.OnPluginLoaded(obj)
	end

	stored[obj:GetFolder()] = obj
	loadCache[obj.m_UniqueID] = true
end

function plugin.HasLoaded(obj)
	if (istable(obj)) then
		return loadCache[obj.m_UniqueID]
	elseif (isstring(obj)) then
		return loadCache[obj]
	end

	return false
end

function plugin.Find(id)
	if (stored[id]) then
		return stored[id], id
	else
		for k, v in pairs(stored) do
			if (v.m_UniqueID == id or v:GetFolder() == id or v:GetName() == id) then
				return v, k
			end
		end
	end
end

-- A function to unhook a plugin from cache.
function plugin.RemoveFromCache(id)
	local pluginTable = plugin.Find(id) or (istable(id) and id)

	-- Awful lot of if's and end's.
	if (pluginTable) then
		if (pluginTable.OnUnhook) then
			Try(pluginTable:GetName(), pluginTable.OnUnhook, pluginTable)
		end

		for k, v in pairs(pluginTable) do
			if (isfunction(v) and hooksCache[k]) then
				for index, tab in ipairs(hooksCache[k]) do
					if (tab[2] == pluginTable) then
						table.remove(hooksCache[k], index)
						break
					end
				end
			end
		end
	end
end

-- A function to cache existing plugin's hooks.
function plugin.ReCache(id)
	local pluginTable = plugin.Find(id)

	if (pluginTable) then
		if (pluginTable.OnRecache) then
			Try(pluginTable:GetName(), pluginTable.OnRecache, pluginTable)
		end

		plugin.CacheFunctions(pluginTable)
	end
end

-- A function to remove the plugin entirely.
function plugin.Remove(id)
	local pluginTable, pluginID = plugin.Find(id)

	if (pluginTable) then
		if (pluginTable.OnRemoved) then
			Try(pluginTable:GetName(), pluginTable.OnRemoved, pluginTable)
		end

		plugin.RemoveFromCache(id)

		stored[pluginID] = nil
	end
end

function plugin.GetFilesForClients(basePath, curPath, results)
	results = results or {}

	if (file.IsDir(basePath, "GAME") and !curPath) then
		curPath = curPath or basePath

		local files, dirs = file.Find(curPath.."/*", "LUA", "namedesc")

		for k, v in ipairs(files) do
			if (v:find("cl_") or v:find("sh_") or v:find("shared.lua")) then
				results[curPath.."/"..v] = fileio.Read("gamemodes/"..curPath.."/"..v)
			end
		end

		for k, v in ipairs(dirs) do
			plugin.GetFilesForClients(basePath, curPath.."/"..v, results)
		end
	elseif (basePath:find("cl_") or basePath:find("sh_") or basePath:find("shared.lua")) then
		results[basePath] = fileio.Read("gamemodes/"..basePath)
	end

	return results
end

-- todo: make it work on client dammit
function plugin.OnPluginChanged(fileName)
	if (plugin.Find(fileName) and !file.Exists("gamemodes/"..fileName, "GAME")) then
		print("[Flux] Removing plugin "..fileName)
		plugin.Remove(fileName)

		netstream.Start(nil, "OnPluginRemoved", fileName)
	elseif (!plugin.Find(fileName) and file.Exists("gamemodes/"..fileName, "GAME")) then
		print("[Flux] Detected new plugin "..fileName)
		local data = plugin.Include(fileName)

		netstream.Heavy(nil, "SendPluginFiles", data, plugin.GetFilesForClients(fileName))
		netstream.Start(nil, "OnPluginAdded", fileName)
	end
end

function plugin.Include(folder)
	local hasMainFile = false
	local id = folder:GetFileFromFilename()
	local ext = id:GetExtensionFromFilename()
	local data = {}
	data.folder = folder
	data.id = id
	data.pluginFolder = folder

	if (reloadData[folder] == false) then
		fl.DevPrint("Not reloading plugin: "..folder)
		return
	end

	fl.DevPrint("Loading plugin: "..folder)

	if (ext != "lua") then
		if (SERVER) then
			if (file.Exists(folder.."/plugin.json", "LUA")) then
				local iniData = util.JSONToTable(file.Read(folder.."/plugin.json", "LUA"))
					data.pluginFolder = folder.."/plugin"
					data.pluginMain = "sh_plugin.lua"

					if (file.Exists(data.pluginFolder.."/sh_"..(data.name or id)..".lua", "LUA")) then
						data.pluginMain = "sh_"..(data.name or id)..".lua"
					end
				table.Merge(data, iniData)

				fl.sharedTable.pluginInfo[folder] = data
			end
		else
			table.Merge(data, fl.sharedTable.pluginInfo[folder])
		end
	end

	if (istable(data.depends)) then
		for k, v in ipairs(data.depends) do
			if (!plugin.Require(v)) then
				ErrorNoHalt("[Flux] Not loading the '"..tostring(folder).."' plugin, because one or more of it's dependencies is missing! ("..tostring(v)..")\n")

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

	plugin.IncludeFolders(data.pluginFolder)

	PLUGIN:Register()
	PLUGIN = nil

	return data
end

function plugin.IncludeSchema()
	local schemaInfo = fl.GetSchemaInfo()
	local schemaFolder = fl.GetSchemaFolder().."/schema"
	schemaInfo.folder = schemaFolder

	if (SERVER) then AddCSLuaFile(fl.GetSchemaFolder().."/gamemode/cl_init.lua") end

	Schema = Plugin(schemaInfo.name, schemaInfo)

	util.Include(schemaFolder.."/sh_schema.lua")

	plugin.IncludeFolders(schemaFolder)
	plugin.IncludePlugins(fl.GetSchemaFolder().."/plugins")

	if (schemaInfo.name and schemaInfo.author) then
		MsgC(Color(0, 255, 100, 255), "[Flux] ")
		MsgC(Color(255, 255, 0), schemaInfo.name)
		MsgC(Color(0, 255, 100), " by "..schemaInfo.author.." has been loaded!\n")
	end

	Schema:Register()
end

-- Please specify full file name if requiring a single-file plugin.
function plugin.Require(pluginName)
	if (!isstring(pluginName)) then return false end

	if (!plugin.HasLoaded(pluginName)) then
		local searchPaths = {
			"flux/plugins/",
			(fl.GetSchemaFolder() or "flux").."/plugins/"
		}

		for k, v in ipairs(searchPaths) do
			if (file.Exists(v..pluginName, "LUA")) then
				plugin.Include(v..pluginName)

				return true
			end
		end
	else
		return true
	end

	return false
end

function plugin.IncludePlugins(folder)
	local files, folders = file.Find(folder.."/*", "LUA")

	for k, v in ipairs(files) do
		if (v:GetExtensionFromFilename() == "lua") then
			plugin.Include(folder.."/"..v)
		end
	end

	for k, v in ipairs(folders) do
		plugin.Include(folder.."/"..v)
	end
end

function plugin.AddExtra(strExtra)
	if (!isstring(strExtra)) then return end

	table.insert(extras, strExtra)
end

function plugin.IncludeFolders(folder)
	for k, v in ipairs(extras) do
		if (plugin.Call("PluginIncludeFolder", v, folder) == nil) then
			if (v == "items") then
				item.IncludeItems(folder.."/items/")
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

	function hook.Call(name, gm, ...)
		if (hooksCache[name]) then
			for k, v in ipairs(hooksCache[name]) do
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

	-- This function DOES NOT call GM: (gamemode) hooks!
	-- It only calls plugin, schema and hook.Add'ed hooks!
	function plugin.Call(name, ...)
		return hook.Call(name, nil, ...)
	end
end

if (CLIENT) then
	netstream.Hook("SendPluginFiles", function(data, files)
		print("[Flux] Detected new plugin named "..data.id..".")

		PLUGIN = Plugin(data.id, data)

		for k, v in pairs(files) do
			RunString(v)
		end

		PLUGIN:Register()
		PLUGIN = nil
	end)
end
