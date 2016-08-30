--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

rw.core = rw.core or {};
library = library or {};
library.stored = library.stored or {};

-- A function to get lowercase type of an object.
function typeof(obj)
	return type(obj):lower();
end;

-- A function to print a prefixed message.
function rw.core:Print(msg)
	if (typeof(msg) != "table") then
		Msg("[Rework] ");
		print(msg);
	else
		print("[Rework] Printing table:");
		PrintTable(msg);
	end;
end;

-- A function to print developer message.
function rw.core:DevPrint(msg)
	if (GM.Devmode) then
		print("[Rework:Dev] "..msg);
	end;
end;

rw.oldFileWrite = rw.oldFileWrite or file.Write;

function file.Write(fileName, content)
	local exploded = string.Explode("/", fileName);
	local curPath = "";

	for k, v in ipairs(exploded) do
		if (string.GetExtensionFromFilename(v) != nil) then
			break;
		end;

		curPath = curPath..v.."/";

		if (!file.Exists(curPath, "DATA")) then
			file.CreateDir(curPath);
		end;
	end;

	return rw.oldFileWrite(fileName, content);
end;

-- A function to include a file based on it's prefix.
function rw.core:Include(file)
	if (SERVER) then
		if (file:find("sh_") or file:find("shared.lua")) then
			AddCSLuaFile(file);
			include(file);
		elseif (file:find("cl_")) then
			AddCSLuaFile(file);
		elseif (file:find("sv_") or file:find("init.lua")) then
			include(file);
		end;
	else
		if (file:find("sh_") or file:find("shared.lua") 
		or file:find("cl_")) then
			include(file);
		end;
	end;
end;

-- A function to include all files in a directory.
function rw.core:IncludeDirectory(dir, recursive, base)
	if (base) then
		if (typeof(base) == "boolean") then
			base = "rework/gamemode/";
		elseif (!base:EndsWith("/")) then 
			base = base.."/";
		end;

		dir = base..dir;
	end;

	if (!dir:EndsWith("/")) then
		dir = dir.."/";
	end;

	if (recursive) then
		local files, folders = _file.Find(dir.."*", "LUA", "namedesc");

		-- First include the files.
		for k, v in ipairs(files) do
			if (v:GetExtensionFromFilename() == "lua") then
				self:Include(dir..v);
			end;
		end;

		-- Then include all directories.
		for k, v in ipairs(folders) do
			self:IncludeDirectory(dir..v, true);
		end;
	else
		local files, _ = _file.Find(dir.."*.lua", "LUA", "namedesc");

		for k, v in ipairs(files) do
			self:Include(dir..v);
		end;
	end;
end;

-- A function to create a new library.
function library.New(name, parent)
	if (typeof(parent) == "table") then
		parent[name] = parent[name] or {};
		return parent[name];
	end;

	library.stored[name] = library.stored[name] or {};
	return library.stored[name];
end;

-- A function to get an existing library.
function library.Get(name, parent)
	if (parent) then
		return parent[name] or library.New(name, parent);
	end;

	return library.stored[name] or library.New(name);
end;

-- Set library table's Metatable so that we can call it like a function.
setmetatable(library, {__call = function(tab, name, parent) return tab.Get(name, parent) end});

-- A function to create a new class. Supports constructors and inheritance.
function library.NewClass(name, parent, extends)
	local class = {
		__call = function(obj, ...)
			if (obj.BaseClass) then
				pcall(obj.BaseClass, obj, ...);
			end;

			if (obj[name]) then
				local success, value = pcall(obj[name], obj, ...);

				if (!success) then
					ErrorNoHalt("["..name.."] Class constructor has failed to run!\n");
				end;
			end;

			return obj;
		end;
	}

	if (typeof(extends) == "table") then
		class.__index = extends;
	end;

	local obj = library.New(name, (parent or _G));
	obj.ClassName = name;
	obj.BaseClass = extends or false;

	setmetatable((parent or _G)[name], class);
end;

function rw.core:GetSchemaFolder()
	if (SERVER) then
		return rw.schema;
	else
		return rw.sharedTable.schemaFolder or "rework";
	end;
end;

function rw.core:Serialize(table)
	if (typeof(table) == "table") then
		local bSuccess, value = pcall(pon.encode, table);

		if (!bSuccess) then
			ErrorNoHalt("[Rework] Failed to serialize a table!\n");
			ErrorNoHalt(value.."\n");
			return "";
		end;

		return value; 
	else
		print("[Rework] You must serialize a table, not "..typeof(table).."!");
		return "";
	end;
end;

function rw.core:Deserialize(strData)
	if (typeof(strData) != "string") then
		print("[Rework] You must deserialize a string, not "..typeof(strData).."!");
		return {};
	end;

	local bSuccess, value = pcall(pon.decode, strData)

	if (!bSuccess) then
		ErrorNoHalt("[Rework] Failed to deserialize a string!\n");
		ErrorNoHalt(value.."\n");
		return {};
	end;

	return value;
end;

function rw.core:IncludeSchema()
	if (SERVER) then
		return plugin.IncludeSchema();
	else
		timer.Create("SchemaLoader", 0.04, 0, function()
			if (rw.sharedTable) then
				timer.Remove("SchemaLoader");
				plugin.IncludeSchema();
			end;
		end)
	end;
end;

function rw.core:IncludePlugins(folder)
	if (SERVER) then
		return plugin.IncludePlugins(folder);
	else
		timer.Create("PluginLoader", 0.04, 0, function()
			if (rw.sharedTable) then
				timer.Remove("PluginLoader");
				plugin.IncludePlugins(folder);
			end;
		end)
	end;
end;

-- A function to get the schema gamemode info.
function rw.core:GetSchemaInfo()
	if (SERVER) then
		if (self.SchemaInfo) then return self.SchemaInfo; end;

		local schemaFolder = string.lower(self:GetSchemaFolder());
		local schemaData = util.KeyValuesToTable(
			fileio.Read("gamemodes/"..schemaFolder.."/"..schemaFolder..".txt")
		);

		if (!schemaData) then
			schemaData = {};
		end;

		if (schemaData["Gamemode"]) then
			schemaData = schemaData["Gamemode"];
		end;

		self.SchemaInfo = {};
			self.SchemaInfo["name"] = schemaData["title"] or "Undefined";
			self.SchemaInfo["author"] = schemaData["author"] or "Undefined";
			self.SchemaInfo["description"] = schemaData["description"] or "Undefined";
			self.SchemaInfo["version"] = schemaData["version"] or "Undefined";
			self.SchemaInfo["folder"] = schemaFolder:gsub("/schema", "");
		return self.SchemaInfo;
	else
		return rw.sharedTable.schemaInfo;
	end;
end;

if (SERVER) then
	rw.sharedTable.schemaInfo = rw.core:GetSchemaInfo();
end;