--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

-- Define basic GM info fields.
GM.Name 		= "Rework";
GM.Author 		= "TeslaCloud Studios";
GM.Website 		= "http://teslacloud.net/";
GM.Email 		= "support@teslacloud.net";

-- Define RW-Specific fields.
GM.Version 		= "0.0.5";
GM.Build 		= "1205";
GM.Description 	= "A free roleplay framework."

-- It would be very nice of you to leave below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.Prefix		= "RW: "; -- Prefix to display in server browser (*Prefix*: *Schema Name*)
GM.NameOverride	= false; -- Set to any string to override schema's browser name.

rw.Devmode		= true; -- If set to true will print some developer info. Moderate console spam.

-- Table aliases.
Rework = rw;
RW = rw;

-- Fix for name conflicts.
_player, _team, _file, _table, _data = player, team, file, table, data;

-- do - end blocks actually let us manage the lifespan
-- of local variables, because when they go out of scope
-- they get automatically garbage-collected, freeing up
-- the memory they have taken.
-- In this particular case it's not necessary, because we
-- already have if - then - end structure, but I thought leaving
-- an example somewhere in the init code would be nice.
do
	if (engine.ActiveGamemode() != "rework") then
		rw.schema = engine.ActiveGamemode();
	else
		local SchemaConVar = GetConVar("schema");

		if (SchemaConVar) then
			rw.schema = rw.schema or SchemaConVar:GetString();
		else
			rw.schema = rw.schema or "cwhl2rp";
		end;
	end;

	rw.sharedTable = rw.sharedTable or {
		schemaFolder = rw.schema,
		pluginInfo = {},
		unloadedPlugins = {}
	};
end;

-- A function to get schema's name.
function rw.GetSchemaName()
	if (Schema) then
		return Schema:GetName();
	else
		return "Unknown";
	end;
end;

-- Called when gamemode's server browser name need to be retrieved.
function GM:GetGameDescription()
	local name = self.Prefix..rw.GetSchemaName();

	if (type(self.NameOverride) == "string") then
		name = self.Prefix..self.NameOverride;
	end;

	return name;
end;

do
	rw.sharedTable.dependencies = rw.sharedTable.dependencies or {};
	rw.sharedTable.disable = rw.sharedTable.disable or {};

	if (SERVER) then
		if (file.Find("gamemodes/"..rw.schema.."/dependencies.lua", "GAME")) then
			rw.sharedTable.dependencies = include(rw.schema.."/dependencies.lua");
		end;

		if (file.Find("gamemodes/"..rw.schema.."/disable.lua", "GAME")) then
			rw.sharedTable.disable = include(rw.schema.."/disable.lua");
		end;
	end;

	function rw.SchemaDepends(id)
		if (rw.sharedTable.dependencies[id]) then
			return true;
		end;

		return false;
	end;

	function rw.SchemaDisabled(id)
		if (rw.sharedTable.disable[id]) then
			return true;
		end;

		return false;
	end;
end;

AddCSLuaFile("core/sh_enums.lua");
AddCSLuaFile("core/sh_util.lua");
AddCSLuaFile("core/sh_core.lua");
include("core/sh_enums.lua");
include("core/sh_util.lua");
include("core/sh_core.lua");

rw.core:Include("core/cl_core.lua");
rw.core:Include("core/sv_core.lua");

-- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
rw.core:IncludeDirectory("core/libraries/required", nil, true);

-- So that we don't get duplicates on refresh.
plugin.ClearCache();

rw.core:IncludeDirectory("core/config", nil, true);
rw.core:IncludeDirectory("core/libraries", nil, true);
rw.core:IncludeDirectory("core/libraries/classes", nil, true);
rw.core:IncludeDirectory("core/libraries/meta", nil, true);
rw.core:IncludeDirectory("core/languages", nil, true);
rw.core:IncludeDirectory("core/groups", nil, true);
rw.core:IncludeDirectory("core/commands", nil, true);
rw.core:IncludeDirectory("core/derma", nil, true);
rw.core:IncludeDirectory("hooks", nil, true);

rw.core:IncludePlugins("rework/plugins");

plugin.Call("RWPluginsLoaded");

rw.core:IncludeSchema();

plugin.Call("RWSchemaLoaded");

if (SERVER) then
	local mysql_host = config.Get("mysql_host");
	local mysql_username = config.Get("mysql_username");
	local mysql_password = config.Get("mysql_password");
	local mysql_database = config.Get("mysql_database");
	local mysql_port = config.Get("mysql_port");

	rw.db:Connect(mysql_host, mysql_username, mysql_password, mysql_database, mysql_port);
end;