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

	if (!file.IsDir(dir, "LUA")) then
		self:DevPrint("'"..dir.."' is not a directory!")
		return;
	end;

	if (!dir:EndsWith("/")) then
		dir = dir.."/";
	end;

	if (recursive) then
		local files, folders = _file.Find(dir.."*", "LUA");

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
		local files, _ = _file.Find(dir.."*.lua", "LUA");

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
	obj.name = name;
	obj.BaseClass = extends or false;

	setmetatable((parent or _G)[name], class);
end;
