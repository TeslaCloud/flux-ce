--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

config.AddToMenu("command_prefixes", "Command Prefixes", "What chat prefixes to consider as command prefixes (*prefix*someCommand, e.g. /someCommand)", "table")
config.AddToMenu("jump_power", "Jump Power", "How high does the player jump by default?", "number", {min = 0, max = 1024, default = 150})
config.AddToMenu("walk_speed", "Walk Speed", "How fast does the player walk?", "number", {min = 0, max = 1024, default = 100})
config.AddToMenu("run_speed", "Run Speed", "How fast does the player run (while holding SHIFT by default)?", "number", {min = 0, max = 1024, default = 200})
config.AddToMenu("crouched_speed", "Crouchwalk Speed", "How fast does the player walk while crouched (while holding CTRL by default)?", "number", {min = 0, max = 1024, default = 55})
config.AddToMenu("respawn_delay", "Respawn Time", "How long does it take for a player to respawn after their death (in seconds)?", "number", {min = 0, max = 1024, default = 30})
config.AddToMenu("character_min_name_len", "Minimum Character Name Length", "The minimum amount of characters that player's name can be.", "number", {min = 1, max = 256, default = 4})
config.AddToMenu("character_max_name_len", "Maximum Character Name Length", "The maximum amount of characters that player's name can be.", "number", {min = 1, max = 256, default = 32})
config.AddToMenu("character_min_desc_len", "Minimum Character Description Length", "The maximum amount of characters that character's description can be.", "number", {min = 1, max = 1024, default = 32})
config.AddToMenu("character_max_desc_len", "Maximum Character Description Length", "The maximum amount of characters that character's description can be.", "number", {min = 1, max = 1024, default = 256})
