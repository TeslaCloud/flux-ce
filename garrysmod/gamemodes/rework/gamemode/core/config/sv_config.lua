--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

config.Set("walk_speed", 100)
config.Set("run_speed", 200)
config.Set("crouched_speed", 55)
config.Set("jump_power", 150)

config.Set("command_prefixes", {"/", "!"})

config.Set("owner_steamid", "STEAM_0:1:14196407")
config.Set("owner_steamid_extra", {"STEAM_0:0:00000000", "STEAM_0:0:00000000"})

config.Set("data_save_interval", 60)
config.Set("player_data_save_interval", 30)

config.Set("character_min_name_len", 6)
config.Set("character_min_desc_len", 32)
config.Set("character_max_name_len", 32)
config.Set("character_max_desc_len", 256)

config.Set("mysql_module", "sqlite", true)
config.Set("mysql_host", "127.0.0.1", true)
config.Set("mysql_username", "root", true)
config.Set("mysql_password", "", true)
config.Set("mysql_database", "rework", true)
config.Set("mysql_port", 3306, true)
config.Set("mysql_socket", nil, true)
config.Set("mysql_flags", nil, true)