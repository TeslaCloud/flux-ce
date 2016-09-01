--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

-- Define basic GM info fields.
GM.Name 		= "Rework";
GM.Author 		= "Mr. Meow and NightAngel";
GM.Website 		= "http://teslacloud.net/";
GM.Email 		= "support@teslacloud.net";

-- Define RW-Specific fields.
GM.Version 		= "0.1";
GM.Build 		= "1159";
GM.Description 	= "A roleplay framework."
GM.Devmode		= true; -- If set to true will print some developer info. Moderate console spam.
GM.Prefix		= "RW: "; -- Prefix to display in server browser (*Prefix*: *Schema Name*)
GM.NameOverride	= false; -- Set to any string to override schema's browser name.

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
	}
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

AddCSLuaFile("core/sh_util.lua");
AddCSLuaFile("core/sh_core.lua");
include("core/sh_util.lua");
include("core/sh_core.lua");

rw.core:Include("core/sh_enums.lua");
rw.core:Include("core/cl_core.lua");
rw.core:Include("core/sv_core.lua");

--[[
if (SERVER) then
	include("core/sv_core.lua");
else
//	include("core/cl_core.lua");
end;
--]]

rw.core:IncludeDirectory("core/libraries", nil, true);
rw.core:IncludeDirectory("core/config", nil, true);
rw.core:IncludeDirectory("core/libraries/classes", nil, true);
rw.core:IncludeDirectory("core/libraries/meta", nil, true);
rw.core:IncludeDirectory("hooks", nil, true);

rw.core:IncludePlugins("rework/plugins");
rw.core:IncludeSchema();
