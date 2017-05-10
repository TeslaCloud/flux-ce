--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

config.AddToMenu("character", "character_min_name_len", "Minimum Character Name Length", "The minimum amount of characters that player's name can be.", "number", {min = 1, max = 256, default = 4})
config.AddToMenu("character", "character_max_name_len", "Maximum Character Name Length", "The maximum amount of characters that player's name can be.", "number", {min = 1, max = 256, default = 32})
config.AddToMenu("character", "character_min_desc_len", "Minimum Character Description Length", "The maximum amount of characters that character's description can be.", "number", {min = 1, max = 1024, default = 32})
config.AddToMenu("character", "character_max_desc_len", "Maximum Character Description Length", "The maximum amount of characters that character's description can be.", "number", {min = 1, max = 1024, default = 256})

local CATEGORY = config.CreateCategory("general", "General Settings", "General settings related to the framework itself.")
CATEGORY:AddTableEditor("command_prefixes", "Command Prefixes", "What chat prefixes to consider as command prefixes (*prefix*someCommand, e.g. /someCommand)")
CATEGORY:AddSlider("walk_speed", "Walk Speed", "How fast does the player walk?", {min = 0, max = 1024, default = 100})
CATEGORY:AddSlider("run_speed", "Run Speed", "How fast does the player run (while holding SHIFT by default)?", {min = 0, max = 1024, default = 200})
CATEGORY:AddSlider("crouched_speed", "Crouchwalk Speed", "How fast does the player walk while crouched (while holding CTRL by default)?", {min = 0, max = 1024, default = 55})
CATEGORY:AddSlider("respawn_delay", "Respawn Time", "How long does it take for a player to respawn after their death (in seconds)?", {min = 0, max = 600, default = 30})