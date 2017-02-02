--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

-- Define basic GM info fields.
GM.Name 		= "Rework";
GM.Author 		= "TeslaCloud Studios";
GM.Website 		= "http://teslacloud.net/";
GM.Email 		= "support@teslacloud.net";

-- Define RW-Specific fields.
GM.Version 		= "0.1.3-indev";
GM.Build 		= "1317";
GM.Description 	= "A free roleplay gamemode framework."

-- It would be very nice of you to leave below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.Prefix		= "RW: "; -- Prefix to display in server browser (*Prefix*: *Schema Name*)
GM.NameOverride	= false; -- Set to any string to override schema's browser name. This overrides prefix too.

rw.Devmode		= true; -- If set to true will print some developer info. Moderate console spam.

-- Table aliases.
Rework = rw;
RW = rw;

-- Fix for name conflicts.
_player, _team, _file, _table, _data, _sound = player, team, file, table, data, sound;

-- do - end blocks let us manage the lifespan of the
-- local variables, because when they go out of scope
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
			rw.schema = rw.schema or "reborn";
		end;
	end;

	-- Shared table contains the info that will be networked
	-- to clients automatically when they load.
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

-- Called when gamemode's server browser name needs to be retrieved.
function GM:GetGameDescription()
	local nameOverride = self.NameOverride;

	return (isstring(nameOverride) and nameOverride) or self.Prefix..rw.GetSchemaName();
end;

do
	local schemaFolder = rw.schema;

	rw.sharedTable.dependencies = rw.sharedTable.dependencies or {};
	rw.sharedTable.disable = rw.sharedTable.disable or {};

	if (SERVER) then
		if (file.Exists("gamemodes/"..schemaFolder.."/dependencies.lua", "GAME")) then
			rw.sharedTable.dependencies = include(schemaFolder.."/dependencies.lua");
		end;

		if (file.Exists("gamemodes/"..schemaFolder.."/disable.lua", "GAME")) then
			rw.sharedTable.disable = include(schemaFolder.."/disable.lua");
		end;
	end;

	function rw.SchemaDepends(id)
		return rw.sharedTable.dependencies[id];
	end;

	function rw.SchemaDisabled(id)
		return rw.sharedTable.disable[id];
	end;
end;

AddCSLuaFile("core/sh_enums.lua");
AddCSLuaFile("core/sh_util.lua");
AddCSLuaFile("core/sh_core.lua");
include("core/sh_enums.lua");
include("core/sh_util.lua");
include("core/sh_core.lua");

util.Include("core/cl_core.lua");
util.Include("core/sv_core.lua");

-- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
util.IncludeDirectory("core/libraries/required", true);

-- So that we don't get duplicates on refresh.
plugin.ClearCache();

util.IncludeDirectory("core/config", true);
util.IncludeDirectory("core/libraries", true);
util.IncludeDirectory("core/libraries/classes", true);
util.IncludeDirectory("core/libraries/meta", true);
util.IncludeDirectory("core/languages", true);
rw.admin:IncludeGroups("rework/gamemode/core/groups");
util.IncludeDirectory("core/commands", true);
util.IncludeDirectory("core/derma", true);
item.IncludeItems("rework/gamemode/core/items");

if (theme or SERVER) then
	pipeline.Register("theme", function(uniqueID, fileName, pipe)
		if (CLIENT) then
			THEME = Theme(uniqueID);

			util.Include(fileName);

			THEME:Register(); THEME = nil;
		else
			util.Include(fileName);
		end;
	end);

	-- Theme factory is needed for any other themes that may be in the themes folder.
	pipeline.Include("theme", "core/themes/cl_theme_factory.lua");

	pipeline.IncludeDirectory("theme", "rework/gamemode/core/themes");
end;

util.IncludeDirectory("hooks", true);
rw.core:IncludePlugins("rework/plugins");

hook.Run("RWPluginsLoaded");

rw.core:IncludeSchema();

hook.Run("RWSchemaLoaded");