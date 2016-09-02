--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
	player:SetDTBool(BOOL_INITIALIZED, true);
end);

function GM:PlayerSetModel(player)
	player:SetModel("models/humans/group01/male_02.mdl");
end;

function GM:PlayerInitialSpawn(player)
	player_manager.SetPlayerClass(player, "rePlayer");
	player_manager.RunClass(player, "Spawn");

	player:SetUserGroup("user");

	if (player:SteamID() == rw.config:Get("owner_steamid")) then
		player:SetUserGroup("owner");
	end;

	player:SendConfig();
	player:SyncNetVars();

	ServerLog(player:Name().." ("..player:GetUserGroup()..") has connected to the server.");

	netstream.Start(player, "SharedTables", rw.sharedTable);
end;

function GM:PlayerSpawn(player)
	player_manager.SetPlayerClass(player, "rePlayer");
	player_manager.RunClass(player, "Spawn");

	self:PlayerSetModel(player);

	player:SetCollisionGroup(COLLISION_GROUP_PLAYER);
	player:SetMaterial("");
	player:SetMoveType(MOVETYPE_WALK);
	player:Extinguish();
	player:UnSpectate();
	player:GodDisable();

	player:SetCrouchedWalkSpeed(rw.config:Get("crouched_speed"));
	player:SetWalkSpeed(rw.config:Get("walk_speed"));
	player:SetJumpPower(rw.config:Get("jump_power"));
	player:SetRunSpeed(rw.config:Get("run_speed"));

	local oldHands = player:GetHands();

	if (IsValid(oldHands)) then
		oldHands:Remove();
	end;

	local handsEntity = ents.Create("gmod_hands");

	if (IsValid(handsEntity)) then
		player:SetHands(handsEntity);
		handsEntity:SetOwner(player);

		local info = player_manager.RunClass(player, "GetHandsModel");

		if (info) then
			handsEntity:SetModel(info.model);
			handsEntity:SetSkin(info.skin);
			handsEntity:SetBodyGroups(info.body);
		end;

		local viewModel = player:GetViewModel(0);
		handsEntity:AttachToViewmodel(viewModel);

		viewModel:DeleteOnRemove(handsEntity);
		player:DeleteOnRemove(handsEntity);

		handsEntity:Spawn();
	end;
end;

function GM:OnPluginFileChange(fileName)
	plugin.OnPluginChanged(fileName);
end;

function GM:GetFallDamage(player, speed)
	local fallDamage = plugin.Call("RWGetFallDamage", player, speed);

	if (speed < 660) then
		speed = speed - 250;
	end;

	if (!fallDamage) then
		fallDamage = 100 * ((speed) / 850);
	end;

	return fallDamage;
end;

function GM:PlayerShouldTakeDamage(player, attacker)
	if (!plugin.Call("RWPlayerShouldTakeDamage")) then
		return true;
	end;
end;

function GM:PlayerSay(player, text, bIsTeam)
	if (text:IsCommand()) then
		text = text:utf8sub(2, text:utf8len()); -- one step less for interpreter.
		rw.command:Interpret(player, text);
		return "";
	end;
end;