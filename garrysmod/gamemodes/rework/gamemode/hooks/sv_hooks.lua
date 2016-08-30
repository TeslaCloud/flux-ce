--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

function GM:PlayerInitialSpawn(player)
	player_manager.SetPlayerClass(player, "rePlayer");
	player_manager.RunClass(player, "Spawn");

	player:SendConfig();
	player:SyncNetVars();

	netstream.Start(player, "SharedTables", rw.sharedTable);

	player:SetDTBool(BOOL_INITIALIZED, true);
end;

function GM:PlayerSpawn(player)
	player_manager.SetPlayerClass(player, "rePlayer");
	player_manager.RunClass(player, "Spawn");
end;

function GM:OnPluginFileChange(fileName)
	plugin.OnPluginChanged(fileName);
end;