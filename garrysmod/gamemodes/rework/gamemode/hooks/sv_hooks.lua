--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

function GM:PostRestoreCharacters(player)
	player:SetDTBool(BOOL_INITIALIZED, true);
end;

function GM:PlayerSetModel(player)
	if (player:IsBot()) then
		player:SetModel("models/humans/group01/male_02.mdl");
	elseif (player:HasInitialized()) then
		player:SetModel(player:GetNetVar("ModelPath"));
	end;
end;

function GM:PlayerInitialSpawn(player)
	player_manager.SetPlayerClass(player, "rePlayer");
	player_manager.RunClass(player, "Spawn");

	player:SetUserGroup("user");

	rw.player:Restore(player);

	if (player:IsBot()) then
		player:SetInitialized(true);
		return;
	end;

	player:SendConfig();
	player:SyncNetVars();
	item.SendToPlayer(player)

	player:SetNoDraw(true);
	player:SetNotSolid(true);
	player:Lock();

	timer.Simple(1, function()
		if (IsValid(player)) then
			player:KillSilent();
			player:StripAmmo();
		end;
	end);

	netstream.Start(player, "SharedTables", rw.sharedTable);
	netstream.Start(nil, "PlayerInitialSpawn", player:EntIndex());
end;

function GM:PlayerDeath(player, inflictor, attacker) end;

function GM:DoPlayerDeath(player, attacker, damageInfo) end;

function GM:PlayerDisconnected(player)
	netstream.Start(nil, "PlayerDisconnected", player:EntIndex());
end;

function GM:PlayerUseItemEntity(player, entity, itemTable)
	netstream.Start(player, "PlayerUseItemEntity", entity);
end;

function GM:OnPlayerRestored(player)
	if (player:SteamID() == config.Get("owner_steamid")) then
		player:SetUserGroup("owner");
	end;

	for k, v in ipairs(config.Get("owner_steamid_extra")) do
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

	player:SetCrouchedWalkSpeed(config.Get("crouched_speed"));
	player:SetWalkSpeed(config.Get("walk_speed"));
	player:SetJumpPower(config.Get("jump_power"));
	player:SetRunSpeed(config.Get("run_speed"));

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
	player:SetNoDraw(false)
	player:UnLock()
	player:SetNotSolid(false)

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
	return plugin.Call("RWPlayerShouldTakeDamage", player, attacker) or true;
end;

function GM:ChatboxPlayerSay(player, message)
	if (message.isCommand) then
		rw.command:Interpret(player, message.text);
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

function GM:InitPostEntity()
	item.Load();

	plugin.Call("RWInitPostEntity");
end;

function GM:DatabaseConnected() end;

function GM:PreSaveCharacter(player, char, index)
	local prepared = {};

	prepared.steamID = player:SteamID();
	prepared.name = char.name;
	prepared.physDesc = char.physDesc or "This character has no physical description set!";
	prepared.faction = char.faction or "player";
	prepared.class = char.class;
	prepared.model = char.model or "models/humans/group01/male_02.mdl";
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
	prepared.physDesc = char.physDesc;
	prepared.faction = char.faction;
	prepared.class = char.class or "";
	prepared.inventory = util.JSONToTable(char.inventory or "");
	prepared.ammo = util.JSONToTable(char.ammo or "");
	prepared.money = tonumber(char.money or "0");
	prepared.charPermissions = util.JSONToTable(char.charPermissions or "");
	prepared.data = util.JSONToTable(char.data or "");
	prepared.uniqueID = tonumber(char.uniqueID or index);
	prepared.key = char.key;

	return prepared;
end;

function GM:OnActiveCharacterSet(player, character)
	player:Spawn();
	player:SetModel(character.model or "models/humans/group01/male_02.mdl");

	plugin.Call("PostCharacterLoaded", player, character);
end;

function GM:PostCharacterLoaded(player, character)
	netstream.Start(player, "PostCharacterLoaded", character.uniqueID);
end;

function GM:OneSecond()
	if (!rw.nextSaveData) then
		rw.nextSaveData = CurTime() + config.Get("data_save_interval");
	elseif (rw.nextSaveData >= CurTime()) then
		hook.Run("RWSaveData");
		rw.nextSaveData = CurTime() + config.Get("data_save_interval");
	end;
end;

function GM:PlayerOneSecond(player, curTime)
	if (!player.nextSaveData) then
		player.nextSaveData = curTime + config.Get("player_data_save_interval");
	elseif (player.nextSaveData >= curTime) then
		hook.Run("PlayerSaveData", player);
		player.nextSaveData = curTime + config.Get("player_data_save_interval");
	end;
end;

function GM:PlayerSaveData(player)
	player:SaveCharacter();
end;

-- Awful awful awful code, but it's kinda necessary in some rare cases.
-- Avoid using PlayerThink whenever possible though.
do
	local thinkDelay = 1 * 0.125;
	local secondDelay = 1;

	function GM:PlayerPostThink(player)
		local curTime = CurTime();

		if ((player.rwNextThink or 0) <= curTime) then
			hook.Run("PlayerThink", player, curTime);
			player.rwNextThink = curTime + thinkDelay;
		end;

		if ((player.rwNextSecond or 0) <= curTime) then
			hook.Run("PlayerOneSecond", player, curTime);
			player.rwNextSecond = curTime + secondDelay;
		end;
	end;
end;