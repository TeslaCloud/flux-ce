--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

rw.config:Set("walk_speed", 100);
rw.config:Set("run_speed", 200);
rw.config:Set("crouched_speed", 55);
rw.config:Set("jump_power", 150);

rw.config:Set("command_prefixes", {"/", "!"});

rw.config:Set("owner_steamid", "STEAM_0:1:14196407");
rw.config:Set("owner_steamid_extra", {"STEAM_0:0:00000000", "STEAM_0:0:00000000"});

rw.config:Set("mysql_module", "sqlite");
rw.config:Set("mysql_host", "127.0.0.1");
rw.config:Set("mysql_username", "root");
rw.config:Set("mysql_password", "");
rw.config:Set("mysql_database", "rework");
rw.config:Set("mysql_port", 3306);
rw.config:Set("mysql_socket", nil);
rw.config:Set("mysql_flags", nil);