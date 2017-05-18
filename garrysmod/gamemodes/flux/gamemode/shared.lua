--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- Define basic GM info fields.
GM.Name 		= "Flux"
GM.Author 		= "TeslaCloud Studios"
GM.Website 		= "http://teslacloud.net/"
GM.Email 		= "support@teslacloud.net"

-- Define Flux-Specific fields.
GM.Version 		= "0.2.5-indev"
GM.Date			= "5/18/2017"
GM.Build 		= "1422"
GM.Description 	= "A free roleplay gamemode framework."

-- It would be very nice of you to leave below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.Prefix		= "FL: " -- Prefix to display in server browser (*Prefix*: *Schema Name*)
GM.NameOverride	= false -- Set to any string to override schema's browser name. This overrides the prefix too.

fl.Devmode		= true -- If set to true will print some developer info. Moderate console spam.

-- Fix for the name conflicts.
_player, _team, _file, _table, _data, _sound = player, team, file, table, data, sound

-- do - end blocks let us manage the lifespan of the
-- local variables, because when they go out of scope
-- they get automatically garbage-collected, freeing up
-- the memory they have taken.
-- In this particular case it's not necessary, because we
-- already have if - then - end structure, but I thought leaving
-- an example somewhere in the init code would be nice.
do
	if (engine.ActiveGamemode() != "flux") then
		fl.schema = engine.ActiveGamemode()
	else
		local SchemaConVar = GetConVar("schema")

		if (SchemaConVar) then
			fl.schema = fl.schema or SchemaConVar:GetString()
		else
			fl.schema = fl.schema or "reborn"
		end
	end

	-- Shared table contains the info that will be networked
	-- to clients automatically when they load.
	fl.sharedTable = fl.sharedTable or {
		schemaFolder = fl.schema,
		pluginInfo = {},
		unloadedPlugins = {}
	}
end

-- A function to get schema's name.
function fl.GetSchemaName()
	if (Schema) then
		return Schema:GetName()
	else
		return "Unknown"
	end
end

-- Called when gamemode's server browser name needs to be retrieved.
function GM:GetGameDescription()
	local nameOverride = self.NameOverride

	return (isstring(nameOverride) and nameOverride) or self.Prefix..fl.GetSchemaName()
end

if (fl.initialized and fl.Devmode) then
	fl.DevPrint("Starting reloading core files. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

AddCSLuaFile("core/sh_util.lua")
include("core/sh_util.lua")

util.Include("core/sh_enums.lua")
util.Include("core/sh_core.lua")
util.Include("core/cl_core.lua")
util.Include("core/sv_core.lua")

if (fl.Devmode) then
	fl.DevPrint("Loaded core files. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

-- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
util.IncludeDirectory("core/libraries/required", true)

-- So that we don't get duplicates on refresh.
plugin.ClearCache()

if (fl.Devmode) then
	fl.DevPrint("Loaded essential libraries and purged cache. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

util.IncludeDirectory("core/config", true)
util.IncludeDirectory("core/libraries", true)
util.IncludeDirectory("core/libraries/classes", true)
util.IncludeDirectory("core/libraries/meta", true)
util.IncludeDirectory("languages", true)
util.IncludeDirectory("core/ui/model", true)
util.IncludeDirectory("core/ui/view/base", true)
util.IncludeDirectory("core/ui/view", true)
util.IncludeDirectory("core/ui/controller", true)
util.IncludeDirectory("core/items/bases", true)
item.IncludeItems("flux/gamemode/core/items")

if (fl.Devmode) then
	fl.DevPrint("Loaded all libraries and stock plugin data. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

if (theme or SERVER) then
	pipeline.Register("theme", function(uniqueID, fileName, pipe)
		if (CLIENT) then
			THEME = Theme(uniqueID)

			util.Include(fileName)

			THEME:Register() THEME = nil
		else
			util.Include(fileName)
		end
	end)

	-- Theme factory is needed for any other themes that may be in the themes folder.
	pipeline.Include("theme", "core/themes/cl_theme_factory.lua")

	pipeline.IncludeDirectory("theme", "flux/gamemode/core/themes")
end

pipeline.IncludeDirectory("tool", "flux/gamemode/core/tools")

if (fl.Devmode) then
	fl.DevPrint("Loaded tools. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

util.IncludeDirectory("hooks", true)

if (fl.Devmode) then
	fl.DevPrint("Loaded hooks. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

fl.IncludePlugins("flux/plugins")

if (fl.Devmode) then
	fl.DevPrint("Loaded Flux Core plugins. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

hook.Run("FluxPluginsLoaded")

fl.IncludeSchema()

if (fl.Devmode) then
	fl.DevPrint("Loaded schema. ["..math.Round(os.clock() - fl.startTime, 3).."]")
end

hook.Run("FluxSchemaLoaded")