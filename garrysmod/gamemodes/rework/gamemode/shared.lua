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
GM.Build 		= "1158";
GM.Description 	= "A roleplay framework."
GM.Devmode		= true; -- If set to true will print some developer info. Moderate console spam.
GM.Prefix		= "RW: "; -- Prefix to display in server browser (*Prefix*: *Schema Name*)
GM.NameOverride	= false; -- Set to any string to override schema's browser name.

-- Table aliases.
Rework = rw;
RW = rw;

-- Fix for name conflicts.
_player, _team, _file = player, team, file;

-- do - end blocks actually let us manage the lifespan
-- of local variables, because when they go out of scope
-- they get automatically garbage-collected, freeing up
-- the memory they have taken.
do
	local SchemaConVar = GetConVar("schema");

	if (SchemaConVar) then
		rw.schema = rw.schema or SchemaConVar:GetString();
	else
		rw.schema = rw.schema or "cwhl2rp";
	end;
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

AddCSLuaFile("core/sh_core.lua");
AddCSLuaFile("core/cl_core.lua");
include("core/sh_core.lua");

if (SERVER) then
	include("core/sv_core.lua");
else
	include("core/cl_core.lua");
end;

rw.core:IncludeDirectory("hooks", nil, true);
