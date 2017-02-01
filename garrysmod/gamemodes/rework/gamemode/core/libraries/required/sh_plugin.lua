--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (plugin) then return; end;

library.New("plugin", _G);

local stored = {};
local hooksCache = {};
local reloadData = {};
local extras = {
	"libraries",
	"classes",
	"meta",
	"config",
	"languages",
	"factions",
	"items",
	"commands",
	"groups",
	"derma",
};

function plugin.GetStored()
	return stored;
end;

function plugin.GetCache()
	return hooksCache;
end;

function plugin.ClearCache()
	table.Empty(hooksCache);
end;

Class "Plugin";

function Plugin:Plugin(name, data)
	self.m_Name = name or data.name or "Unknown Plugin";
	self.m_Author = data.author or "Unknown Author";
	self.m_Folder = data.folder or name:gsub(" ", "_"):lower();
	self.m_Description = data.description or "Undescribed plugin or schema.";
	self.m_uniqueID = data.id or name:gsub(" ", "_"):lower() or "unknown";

	table.Merge(self, data);
end;

function Plugin:GetName()
	return self.m_Name;
end;

function Plugin:GetFolder()
	return self.m_Folder;
end;

function Plugin:GetAuthor()
	return self.m_Author;
end;

function Plugin:GetDescription()
	return self.m_Description;
end;

function Plugin:SetName(name)
	self.m_Name = name or self.m_Name or "Unknown Plugin";
end;

function Plugin:SetAuthor(author)
	self.m_Author = author or self.m_Author or "Unknown";
end;

function Plugin:SetDescription(desc)
	self.m_Description = desc or self.m_Description or "No description provided!";
end;

function Plugin:SetData(data)
	table.Merge(self, data);
end;

function Plugin:SetAlias(alias)
	if (isstring(alias)) then
		_G[alias] = self;
	end;
end;

function Plugin:Register()
	plugin.Register(self);
end;

function plugin.CacheFunctions(obj, id)
	for k, v in pairs(obj) do
		if (isfunction(v)) then
			hooksCache[k] = hooksCache[k] or {};
			table.insert(hooksCache[k], {v, obj, id = id});
		end;
	end;
end;

function plugin.AddHooks(id, obj)
	plugin.CacheFunctions(obj, id);
end;

function plugin.RemoveHooks(id)
	for k, v in pairs(hooksCache) do
		for k2, v2 in ipairs(v) do
			if (v2.id and v2.id == id) then
				hooksCache[k][k2] = nil;
			end;
		end;
	end;
end;

function plugin.Register(obj)
	plugin.CacheFunctions(obj);

	if (obj.ShouldRefresh == false) then
		reloadData[obj:GetFolder()] = false;
	else
		reloadData[obj:GetFolder()] = true;
	end

	stored[obj:GetFolder()] = obj;
end;

function plugin.Find(id)
	if (stored[id]) then
		return stored[id], id;
	else
		for k, v in pairs(stored) do
			if (v.m_uniqueID == id or v:GetFolder() == id or v:GetName() == id) then
				return v, k;
			end;
		end;
	end;
end;

-- A function to unhook a plugin from cache.
function plugin.RemoveFromCache(id)
	local pluginTable = plugin.Find(id) or (istable(id) and id);

	-- Awful lot of if's and end's.
	if (pluginTable) then
		if (pluginTable.OnUnhook) then
			Try(pluginTable:GetName(), pluginTable.OnUnhook, pluginTable);
		end;

		for k, v in pairs(pluginTable) do
			if (isfunction(v) and hooksCache[k]) then
				for index, tab in ipairs(hooksCache[k]) do
					if (tab[2] == pluginTable) then
						table.remove(hooksCache[k], index);
						break;
					end;
				end;
			end;
		end;
	end;
end;

-- A function to cache existing plugin's hooks.
function plugin.ReCache(id)
	local pluginTable = plugin.Find(id);

	if (pluginTable) then
		if (pluginTable.OnRecache) then
			Try(pluginTable:GetName(), pluginTable.OnRecache, pluginTable);
		end;

		plugin.CacheFunctions(pluginTable);
	end;
end;

-- A function to remove the plugin entirely.
function plugin.Remove(id)
	local pluginTable, pluginID = plugin.Find(id);

	if (pluginTable) then
		if (pluginTable.OnRemoved) then
			Try(pluginTable:GetName(), pluginTable.OnRemoved, pluginTable);
		end;

		plugin.RemoveFromCache(id);

		stored[pluginID] = nil;
	end;
end;

function plugin.GetFilesForClients(basePath, curPath, results)
	results = results or {};

	if (file.IsDir(basePath, "GAME") and !curPath) then
		curPath = curPath or basePath;

		local files, dirs = file.Find(curPath.."/*", "LUA", "namedesc");

		for k, v in ipairs(files) do
			if (v:find("cl_") or v:find("sh_") or v:find("shared.lua")) then
				results[curPath.."/"..v] = fileio.Read("gamemodes/"..curPath.."/"..v);
			end;
		end;

		for k, v in ipairs(dirs) do
			plugin.GetFilesForClients(basePath, curPath.."/"..v, results);
		end;
	elseif (basePath:find("cl_") or basePath:find("sh_") or basePath:find("shared.lua")) then
		results[basePath] = fileio.Read("gamemodes/"..basePath);
	end;

	return results;
end;

-- todo: make it work on client dammit
function plugin.OnPluginChanged(fileName)
	if (plugin.Find(fileName) and !file.Exists("gamemodes/"..fileName, "GAME")) then
		print("[Rework] Removing plugin "..fileName);
		plugin.Remove(fileName);

		netstream.Start(nil, "OnPluginRemoved", fileName);
	elseif (!plugin.Find(fileName) and file.Exists("gamemodes/"..fileName, "GAME")) then
		print("[Rework] Detected new plugin "..fileName);
		local data = plugin.Include(fileName);

		netstream.Heavy(nil, "SendPluginFiles", data, plugin.GetFilesForClients(fileName));
		netstream.Start(nil, "OnPluginAdded", fileName);
	end;
end;

function plugin.Include(folder)
	local hasMainFile = false;
	local id = folder:GetFileFromFilename();
	local ext = id:GetExtensionFromFilename();
	local data = {};
	data.folder = folder;
	data.id = id;
	data.pluginFolder = folder;

	if (reloadData[folder] == false) then
		rw.core:DevPrint("Not reloading plugin: "..folder);
		return;
	end;

	rw.core:DevPrint("Loading plugin: "..folder);

	if (ext != "lua") then
		if (SERVER) then
			if (file.Exists(folder.."/plugin.ini", "LUA")) then
				local iniData = util.JSONToTable(file.Read(folder.."/plugin.ini", "LUA"));
					data.pluginFolder = folder.."/plugin";
					data.pluginMain = "sh_plugin.lua";

					if (file.Exists(data.pluginFolder.."/sh_"..(data.name or id)..".lua", "LUA")) then
						data.pluginMain = "sh_"..(data.name or id)..".lua";
					end;
				table.Merge(data, iniData);

				rw.sharedTable.pluginInfo[folder] = data;
			end;
		else
			table.Merge(data, rw.sharedTable.pluginInfo[folder]);
		end;
	end;

	PLUGIN = Plugin(id, data);

	if (stored[folder]) then
		PLUGIN = stored[folder];
	end;

	if (ext != "lua") then
		util.Include(data.pluginFolder.."/"..data.pluginMain);
	else
		if (file.Exists(folder, "LUA")) then
			util.Include(folder);
		end;
	end;

	plugin.IncludeFolders(data.pluginFolder);

	PLUGIN:Register();
	PLUGIN = nil;

	return data;
end;

function plugin.IncludeSchema()
	local schemaInfo = rw.core:GetSchemaInfo();
	local schemaFolder = rw.core:GetSchemaFolder().."/schema";
	schemaInfo.folder = schemaFolder;

	Schema = Plugin(schemaInfo.name, schemaInfo);

	util.Include(schemaFolder.."/sh_schema.lua");

	plugin.IncludeFolders(schemaFolder);
	plugin.IncludePlugins(rw.core:GetSchemaFolder().."/plugins");

	if (schemaInfo.name and schemaInfo.author) then
		MsgC(Color(0, 255, 100, 255), "[Rework] ");
		MsgC(Color(255, 255, 0), schemaInfo.name);
		MsgC(Color(0, 255, 100), " by "..schemaInfo.author.." has been loaded!\n");
	end;

	Schema:Register();
end;

function plugin.IncludePlugins(folder)
	local files, folders = file.Find(folder.."/*", "LUA");

	for k, v in ipairs(files) do
		if (v:GetExtensionFromFilename() == "lua") then
			plugin.Include(folder.."/"..v);
		end;
	end;

	for k, v in ipairs(folders) do
		plugin.Include(folder.."/"..v);
	end;
end;

function plugin.IncludeFolders(folder)
	for k, v in ipairs(extras) do
		if (hook.Run("PluginIncludeFolder", v, folder) == nil) then
			if (v == "items") then
				item.IncludeItems(folder.."/items/");
			elseif (v == "groups") then
				rw.admin:IncludeGroups(folder.."/groups/");
			elseif (v == "factions") then
				faction.IncludeFactions(folder.."/factions/");
			else
				util.IncludeDirectory(folder.."/"..v);
			end;
		end;
	end;
end;

do
	local oldHookCall = plugin.OldHookCall or hook.Call;
	plugin.OldHookCall = oldHookCall;

	function hook.Call(name, gm, ...)
		if (hooksCache[name]) then
			for k, v in ipairs(hooksCache[name]) do
				local success, a, b, c, d, e, f = pcall(v[1], v[2], ...);

				if (!success) then
					ErrorNoHalt("[Rework:"..(v.id or v[2]:GetName()).."] The "..name.." hook has failed to run!\n");
					ErrorNoHalt(tostring(a), "\n");

					if (name != "OnHookError") then
						hook.Call("OnHookError", gm, name, v);
					end;
				elseif (a != nil) then
					return a, b, c, d, e, f;
				end;
			end;
		end;

		return oldHookCall(name, gm, ...);
	end;

	-- This function DOES NOT call GM: (gamemode) hooks!
	-- It only calls plugin, schema and hook.Add'ed hooks!
	function plugin.Call(name, ...)
		return hook.Call(name, nil, ...);
	end;
end;

if (CLIENT) then
	netstream.Hook("SendPluginFiles", function(data, files)
		print("[Rework] Detected new plugin named "..data.id..".");

		PLUGIN = Plugin(data.id, data);

		for k, v in pairs(files) do
			RunString(v);
		end;

		PLUGIN:Register();
		PLUGIN = nil;
	end);
end;
