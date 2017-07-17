--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

DEFINE_BASECLASS("gamemode_base")

function GM:DoPlayerDeath(player, attacker, damageInfo) end

function GM:Initialize()
	local configFile = fileio.Read("gamemodes/flux/flux.cfg")

	if (configFile) then
		config.Import(configFile, CONFIG_FLUX)
	end

	local mysql_host = config.Get("mysql_host")
	local mysql_username = config.Get("mysql_username")
	local mysql_password = config.Get("mysql_password")
	local mysql_database = config.Get("mysql_database")
	local mysql_port = config.Get("mysql_port")

	if (mysql_host == "sqlite" or mysql_host == "example.com" or mysql_host == "example" or mysql_host == "") then
		fl.db.Module = "sqlite"
	end

	fl.db:Connect(mysql_host, mysql_username, mysql_password, mysql_database, mysql_port)
end

function GM:InitPostEntity()
	local toolGun = weapons.GetStored("gmod_tool")

	for k, v in pairs(fl.tool:GetAll()) do
		toolGun.Tool[v.Mode] = v
	end

	plugin.Call("FLInitPostEntity")
end

function GM:PlayerInitialSpawn(player)
	player_manager.SetPlayerClass(player, "flPlayer")
	player_manager.RunClass(player, "Spawn")

	player:SetUserGroup("user")
	player:RestorePlayer()

	if (player:IsBot()) then
		player:SetInitialized(true)

		return
	end

	player:SetNoDraw(true)
	player:SetNotSolid(true)
	player:Lock()

	timer.Simple(1, function()
		if (IsValid(player)) then
			player:KillSilent()
			player:StripAmmo()
		end
	end)

	netstream.Start(nil, "PlayerInitialSpawn", player:EntIndex())
end

function GM:PlayerSpawn(player)
	player_manager.SetPlayerClass(player, "flPlayer")

	hook.Run("PlayerSetModel", player)

	player:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	player:SetMaterial("")
	player:SetMoveType(MOVETYPE_WALK)
	player:Extinguish()
	player:UnSpectate()
	player:GodDisable()

	player:SetCrouchedWalkSpeed(config.Get("crouched_speed") / config.Get("walk_speed"))
	player:SetWalkSpeed(config.Get("walk_speed"))
	player:SetJumpPower(config.Get("jump_power"))
	player:SetRunSpeed(config.Get("run_speed"))

	hook.Run("PostPlayerSpawn", player)

	local oldHands = player:GetHands()

	if (IsValid(oldHands)) then
		oldHands:Remove()
	end

	local handsEntity = ents.Create("gmod_hands")

	if (IsValid(handsEntity)) then
		player:SetHands(handsEntity)
		handsEntity:SetOwner(player)

		local info = player_manager.RunClass(player, "GetHandsModel")

		if (info) then
			handsEntity:SetModel(info.model)
			handsEntity:SetSkin(info.skin)
			handsEntity:SetBodyGroups(info.body)
		end

		local viewModel = player:GetViewModel(0)
		handsEntity:AttachToViewmodel(viewModel)

		viewModel:DeleteOnRemove(handsEntity)
		player:DeleteOnRemove(handsEntity)

		handsEntity:Spawn()
	end
end

function GM:PostPlayerSpawn(player)
	player:SetNoDraw(false)
	player:UnLock()
	player:SetNotSolid(false)

	player_manager.RunClass(player, "Loadout")

	if (player:HasPermission("toolgun")) then
		player:Give("gmod_tool")
	end

	if (player:HasPermission("physgun")) then
		player:Give("weapon_physgun")
	end

	hook.RunClient(player, "PostPlayerSpawn")
end

function GM:PlayerSetModel(player)
	if (player:IsBot()) then
		player:SetModel("models/humans/group01/male_0"..math.random(1, 9)..".mdl")
	elseif (player:HasInitialized()) then
		player:SetModel(player:GetNetVar("model", "models/humans/group01/male_02.mdl"))
	elseif (self.BaseClass.PlayerSetModel) then
		self.BaseClass:PlayerSetModel(player)
	end
end

function GM:PlayerInitialized(player)
	player:SetInitialized(true)

	hook.RunClient(player, "PlayerInitialized")
end

function GM:PlayerDeath(player, inflictor, attacker)
	player:SaveCharacter()

	player:SetNetVar("RespawnTime", CurTime() + config.Get("respawn_delay"))
end

function GM:PlayerDeathThink(player)
	local respawnTime = player:GetNetVar("RespawnTime", 0)

	if (respawnTime <= CurTime()) then
		player:Spawn()
	end

	return false
end

function GM:PlayerDisconnected(player)
	player:SaveCharacter()
	netstream.Start(nil, "PlayerDisconnected", player:EntIndex())
end

function GM:EntityRemoved(entity)
	entity:ClearNetVars()

	self.BaseClass:EntityRemoved(entity)
end

function GM:OnPluginFileChange(fileName)
	plugin.OnPluginChanged(fileName)
end

function GM:GetFallDamage(player, speed)
	local fallDamage = hook.Run("FLGetFallDamage", player, speed)

	if (speed < 660) then
		speed = speed - 250
	end

	if (!fallDamage) then
		fallDamage = 100 * ((speed) / 850)
	end

	return fallDamage
end

function GM:PlayerShouldTakeDamage(player, attacker)
	return hook.Run("FLPlayerShouldTakeDamage", player, attacker) or true
end

function GM:ChatboxPlayerSay(player, message)
	if (message.isCommand) then
		fl.command:Interpret(player, message.text)

		return ""
	end
end

function GM:PlayerSpawnProp(player, model)
	if (!player:HasPermission("spawn_props")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnProp", player, model) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnObject(player, model, skin)
	if (!player:HasPermission("spawn_entities")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnObject", player, model, skin) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnNPC(player, npc, weapon)
	if (!player:HasPermission("spawn_npcs")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnNPC", player, npc, weapon) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnEffect(player, model)
	if (!player:HasPermission("spawn_entities")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnEffect", player, model) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnVehicle(player, model, name, tab)
	if (!player:HasPermission("spawn_vehicles")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnVehicle", player, model, name, tab) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnSWEP(player, weapon, swep)
	if (!player:HasPermission("spawn_sweps")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnSWEP", player, weapon, swep) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnSENT(player, class)
	if (!player:HasPermission("spawn_entities")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnSENT", player, class) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnRagdoll(player, model)
	if (!player:HasPermission("spawn_ragdolls")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnRagdoll", player, model) == false) then
		return false
	end

	return true
end

function GM:PlayerGiveSWEP(player, weapon, swep)
	if (!player:HasPermission("spawn_sweps")) then
		return false
	end

	if (hook.Run("FLPlayerGiveSWEP", player, weapon, swep) == false) then
		return false
	end

	return true
end

function GM:OnPhysgunFreeze(weapon, physObj, entity, player)
	if (player:HasPermission("physgun_freeze")) then
		BaseClass.OnPhysgunFreeze(self, weapon, physObj, entity, player)

		return false
	end
end

function GM:EntityTakeDamage(ent, damageInfo)
	if (IsValid(ent) and ent:IsPlayer()) then
		hook.Run("PlayerTakeDamage", ent, damageInfo)
	end
end

function GM:PlayerTakeDamage(player, damageInfo)
	netstream.Start(player, "PlayerTakeDamage")
end

function GM:OneSecond()
	local curTime = CurTime()
	local sysTime = SysTime()

	if (!fl.nextSaveData) then
		fl.nextSaveData = curTime + 10
	elseif (fl.nextSaveData <= curTime) then
		if (hook.Run("FLShouldSaveData") != false) then
			fl.DevPrint("Saving framework's data...")

			hook.Run("FLSaveData")
		end

		fl.nextSaveData = curTime + config.Get("data_save_interval")
	end

	for k, v in pairs(areas.GetAll()) do
		if (istable(v.polys) and isstring(v.type)) then
			for k2, v2 in ipairs(v.polys) do
				for plyID, player in ipairs(_player.GetAll()) do
					local pos = player:GetPos()

					player.lastArea = player.lastArea or {}
					player.lastArea[v.uniqueID] = player.lastArea[v.uniqueID] or {}

					-- Player hasn't moved since our previous check, no need to check again.
					if (pos == player.lastPos) then continue end

					local z = pos.z + 16 -- Raise player's position by 16 units to compensate for player's height
					local enteredArea = false

					-- First do height checks
					if (z > v2[1].z and z < v.maxH) then
						if (util.VectorIsInPoly(pos, v2)) then
							-- Player entered the area
							if (!table.HasValue(player.lastArea[v.uniqueID], k2)) then
								Try("Areas", areas.GetCallback(v.type), player, v, v2, true, pos, curTime)

								netstream.Start(player, "PlayerEnteredArea", k, k2, pos, curTime)

								table.insert(player.lastArea[v.uniqueID], k2)
							end

							enteredArea = true
						end
					end

					if (!enteredArea) then
						-- Player left the area
						if (table.HasValue(player.lastArea[v.uniqueID], k2)) then
							Try("Areas", areas.GetCallback(v.type), player, v, v2, false, pos, curTime)

							netstream.Start(player, "PlayerLeftArea", k, k2, pos, curTime)

							table.RemoveByValue(player.lastArea[v.uniqueID], k2)
						end
					end
				end
			end
		end
	end

	if (!fl.NextPlayerCountCheck) then
		fl.NextPlayerCountCheck = sysTime + 1800
	elseif (fl.NextPlayerCountCheck <= sysTime) then
		fl.NextPlayerCountCheck = sysTime + 1800

		if (#player.GetAll() == 0) then
			if (hook.Run("ShouldServerAutoRestart") != false) then
				fl.DevPrint("Server is empty, restarting...")
				RunConsoleCommand("changelevel", game.GetMap())
			end
		end
	end
end

function GM:FluxPreLoadPlugins()
	fl.sharedTable.disabledPlugins = data.Load("disabled_plugins", {})
end

function GM:FLSaveData()
	hook.Run("SaveData")
end

function GM:OnCharacterChange(player, oldChar, newCharID)
	player:SaveCharacter()
end

function GM:PlayerOneSecond(player, curTime)
	local pos = player:GetPos()

	if (player.lastPos != pos) then
		hook.Run("PlayerPositionChanged", player, player.lastPos, pos, curTime)
	end

	player.lastPos = pos
end

-- Awful awful awful code, but it's kinda necessary in some rare cases.
-- Avoid using PlayerThink whenever possible though.
do
	local thinkDelay = 1 * 0.125
	local secondDelay = 1
	local nextThink = 0
	local nextSecond = 0

	function GM:Tick()
		local curTime = CurTime()

		if (curTime >= nextThink) then
			local oneSecondTick = (curTime >= nextSecond)

			for k, v in ipairs(player.GetAll()) do
				hook.Call("PlayerThink", self, v, curTime)

				if (oneSecondTick) then
					hook.Call("PlayerOneSecond", self, v, curTime)
				end
			end

			nextThink = curTime + thinkDelay

			if (oneSecondTick) then
				nextSecond = curTime + 1
			end
		end
	end
end