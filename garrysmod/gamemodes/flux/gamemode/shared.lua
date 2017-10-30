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
GM.Version 		= "0.2.9-indev"
GM.VersionNum	= "0.2.9"
GM.Date			= "10/1/2017"
GM.Build 		= "1559"
GM.Description 	= "A free roleplay gamemode framework."

-- It would be very nice of you to leave below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.NameOverride	= false -- Set to any string to override schema's browser name. This overrides the prefix too.

fl.Devmode		= true -- Always set this to true when developing anything for FL. This enables the safe mode on hooks.

-- Fix for the name conflicts.
_player, _team, _file, _table, _sound = player, team, file, table, sound

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
		ErrorNoHalt("==========================\n")
		ErrorNoHalt("==========================\n")
		ErrorNoHalt("You have set your +gamemode to 'flux'!\n")
		ErrorNoHalt("Please set it to your schema's name instead!\n")
		ErrorNoHalt("==========================\n")
		ErrorNoHalt("==========================\n")

		return
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
	return (Schema and Schema:GetName()) or fl.schema or "Unknown"
end

-- Called when gamemode's server browser name needs to be retrieved.
function GM:GetGameDescription()
	local nameOverride = self.NameOverride

	return (isstring(nameOverride) and nameOverride) or "FL - "..fl.GetSchemaName()
end

include("core/sh_util.lua")

util.Include("core/sh_enums.lua")
util.Include("core/sh_core.lua")
util.Include("core/cl_core.lua")
util.Include("core/sv_core.lua")

-- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
util.IncludeDirectory("core/libraries/required", true)

-- So that we don't get duplicates on refresh.
plugin.ClearCache()

util.IncludeDirectory("core/config", true)
util.IncludeDirectory("core/libraries", true)
util.IncludeDirectory("core/libraries/classes", true)
util.IncludeDirectory("core/libraries/meta", true)
util.IncludeDirectory("languages", true)
util.IncludeDirectory("core/ui/controllers", true)
util.IncludeDirectory("core/ui/view/base", true)
util.IncludeDirectory("core/ui/view", true)

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
util.IncludeDirectory("hooks", true)

hook.Run("PreLoadPlugins")

fl.IncludePlugins("flux/plugins")

hook.Run("OnPluginsLoaded")

fl.IncludeSchema()