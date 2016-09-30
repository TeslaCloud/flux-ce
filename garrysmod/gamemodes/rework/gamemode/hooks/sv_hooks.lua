--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
	player:SetDTBool(BOOL_INITIALIZED, true);
end);

function GM:PlayerSetModel(player)
	player:SetModel("models/humans/group01/male_0"..math.random(1, 8)..".mdl");
end;

function GM:PlayerInitialSpawn(player)
	player_manager.SetPlayerClass(player, "rePlayer");
	player_manager.RunClass(player, "Spawn");

	player:SetUserGroup("user");

	rw.player:Restore(player);

	player:SendConfig();
	player:SyncNetVars();

	netstream.Start(player, "SharedTables", rw.sharedTable);
	netstream.Start(nil, "PlayerInitialSpawn", player:EntIndex());
end;

function GM:PlayerDisconnected(player)
	netstream.Start(nil, "PlayerDisconnected", player:EntIndex());
end;

function GM:OnPlayerRestored(player)
	if (player:SteamID() == rw.config:Get("owner_steamid")) then
		player:SetUserGroup("owner");
	end;

	for k, v in ipairs(rw.config:Get("owner_steamid_extra")) do
		if (v == player:SteamID()) then
			player:SetUserGroup("owner");
		end;
	end;

	ServerLog(player:Name().." ("..player:GetUserGroup()..") has connected to the server.");
end;

function GM:PlayerSpawn(player)
	player_manager.SetPlayerClass(player, "rePlayer");

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

	plugin.Call("PostPlayerSpawn", player);
end;

function GM:PostPlayerSpawn(player)
	player_manager.RunClass(player, "Loadout");
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
	if (string.IsCommand(text)) then
		text = text:utf8sub(2, text:utf8len()); -- one step less for interpreter.
		rw.command:Interpret(player, text);
		return "";
	end;
end;

function GM:PlayerSpawnProp(player, model)
	if (!player:HasPermission("spawn_props")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnProp", player, model) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerSpawnObject(player, model, skin)
	if (!player:HasPermission("spawn_objects")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnObject", player, model, skin) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerSpawnNPC(player, npc, weapon)
	if (!player:HasPermission("spawn_npc")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnNPC", player, npc, weapon) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerSpawnEffect(player, model)
	if (!player:HasPermission("spawn_effects")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnEffect", player, model) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerSpawnVehicle(player, model, name, tab)
	if (!player:HasPermission("spawn_vehicles")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnVehicle", player, model, name, tab) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerSpawnSWEP(player, weapon, swep)
	if (!player:HasPermission("spawn_swep")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnSWEP", player, weapon, swep) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerSpawnSENT(player, class)
	if (!player:HasPermission("spawn_sent")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnSENT", player, class) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerSpawnRagdoll(player, model)
	if (!player:HasPermission("spawn_ragdolls")) then
		return false;
	end;

	if (plugin.Call("RWPlayerSpawnRagdoll", player, model) == false) then
		return false;
	end;

	return true;
end;

function GM:PlayerGiveSWEP(player, weapon, swep)
	if (!player:HasPermission("spawn_swep")) then
		return false;
	end;

	if (plugin.Call("RWPlayerGiveSWEP", player, weapon, swep) == false) then
		return false;
	end;

	return true;
end;

function GM:DatabaseConnected()
end;

function GM:PreSaveCharacter(player, char, index)
	local prepared = {};

	prepared.steamID = player:SteamID();
	prepared.name = char.name;
	prepared.faction = char.faction;
	prepared.class = char.class;
	prepared.inventory = util.TableToJSON(char.inventory);
	prepared.ammo = util.TableToJSON(char.ammo);
	prepared.money= char.money;
	prepared.charPermissions = util.TableToJSON(char.charPermissions);
	prepared.data = util.TableToJSON(char.data);
	prepared.uniqueID = char.uniqueID;

	return prepared;
end;

function GM:PreSaveCharacters(player, chars)
	local prepared = {};

	for k, v in ipairs(chars) do
		prepared[k] = plugin.Call("PreSaveCharacter", player, v, k);
	end;

	return prepared;
end;

function GM:PreCharacterRestore(player, index, char)
	local prepared = {};

	prepared.steamID = player:SteamID();
	prepared.name = char.name;
	prepared.faction = char.faction;
	prepared.class = char.class;
	prepared.inventory = util.JSONToTable(char.inventory);
	prepared.ammo = util.JSONToTable(char.ammo);
	prepared.money = tonumber(char.money);
	prepared.charPermissions = util.JSONToTable(char.charPermissions);
	prepared.data = util.JSONToTable(char.data);
	prepared.uniqueID = tonumber(char.uniqueID);

	return prepared;
end;