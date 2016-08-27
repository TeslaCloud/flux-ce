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
GM.Prefix		= "RW: "; -- Prefix to display in server browser (*Prefix*: *Schema Name*)
GM.NameOverride	= false; -- Set to any string to override schema's browser name.

-- Table aliases.
Rework = rw;
RW = rw;

-- Fix for name conflicts.
_player, _team, _file = player, team, file;

do
	local SchemaConVar = GetConVar("schema");

	if (SchemaConVar) then
		rw.schema = rw.schema or SchemaConVar:GetString();
	else
		rw.schema = rw.schema or "cwhl2rp";
	end;
end;

-- Called when gamemode's server browser name need to be retrieved.
function GM:GetGameDescription()
	local name = self.Prefix..(rw.GetSchemaName() or "Unknown");
	
	if (type(self.NameOverride == "string")) then
		name = self.Prefix..self.NameOverride;
	end;
	
	return name;
end;