--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function GM:InitPostEntity()
	item.Load()

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

	fl.player:Restore(player)

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

	self:PlayerSetModel(player)

	player:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	player:SetMaterial("")
	player:SetMoveType(MOVETYPE_WALK)
	player:Extinguish()
	player:UnSpectate()
	player:GodDisable()

	player:SetCrouchedWalkSpeed(config.Get("crouched_speed"))
	player:SetWalkSpeed(config.Get("walk_speed"))
	player:SetJumpPower(config.Get("jump_power"))
	player:SetRunSpeed(config.Get("run_speed"))

	local playerFaction = player:GetFaction()

	if (playerFaction) then
		player:SetTeam(playerFaction.teamID or 1)
	end

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

	hook.Run("PostPlayerSpawn", player)
end

function GM:PostPlayerSpawn(player)
	player:SetNoDraw(false)
	player:UnLock()
	player:SetNotSolid(false)

	player_manager.RunClass(player, "Loadout")

	hook.RunClient(player, "PostPlayerSpawn")
end

function GM:PlayerSetModel(player)
	if (player:IsBot()) then
		player:SetModel("models/humans/group01/male_0"..math.random(1, 9)..".mdl")
	elseif (player:HasInitialized()) then
		player:SetModel(player:GetNetVar("model", "models/humans/group01/male_02.mdl"))
	end
end

function GM:PlayerInitialized(player)
	player:SetInitialized(true)

	hook.RunClient(player, "PlayerInitialized")
end

function GM:PlayerDeath(player, inflictor, attacker)
	player:SaveCharacter()

	player:SetNetVar("RespawnTime", CurTime() + config.Get("flspawn_delay"))
end

function GM:DoPlayerDeath(player, attacker, damageInfo) end

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

function GM:PlayerUseItemEntity(player, entity, itemTable)
	netstream.Start(player, "PlayerUseItemEntity", entity)
end

function GM:PlayerTakeItem(player, itemTable, ...)
	if (IsValid(itemTable.entity)) then
		itemTable.entity:Remove()
		player:GiveItemByID(itemTable.instanceID)
		item.AsyncSaveEntities()
	end
end

function GM:PlayerDropItem(player, instanceID, itemTable, ...)
	if (player:HasItemByID(instanceID)) then
		player:TakeItemByID(instanceID)

		local itemTable = item.FindInstanceByID(instanceID)
		local trace = player:GetEyeTraceNoCursor()
		local distance = trace.HitPos:Distance(player:GetPos())

		if (distance < 150) then
			item.Spawn(trace.HitPos + Vector(0, 0, 4), Angle(0, 0, 0), itemTable)
		else
			item.Spawn(player:EyePos() + trace.Normal * 20, Angle(0, 0, 0), itemTable)
		end

		item.AsyncSaveEntities()
	end
end

function GM:PlayerUseItem(player, itemTable, ...)
	local trace

	if (IsValid(itemTable.entity)) then
		trace = player:GetEyeTraceNoCursor()

		if (!IsValid(trace.Entity)) then return end
		if (trace.Entity != itemTable.entity) then return end
	end

	if (player:HasItemByID(itemTable.instanceID) or trace != nil) then
		if (itemTable.OnUse) then
			local result = itemTable:OnUse(player)

			if (result == true) then
				return
			elseif (result == false) then
				return false
			end
		end

		if (trace != nil) then
			itemTable.entity:Remove()
		else
			player:TakeItemByID(itemTable.instanceID)
		end
	end
end

function GM:OnItemGiven(player, itemTable, slot)
	hook.Run("PlayerInventoryUpdated", player)
end

function GM:OnItemTaken(player, itemTable, slot)
	hook.Run("PlayerInventoryUpdated", player)
end

function GM:PlayerInventoryUpdated(player)
	netstream.Start(player, "RefreshInventory")
end

function GM:OnPlayerRestored(player)
	if (player:SteamID() == config.Get("owner_steamid")) then
		player:SetUserGroup("owner")
	end

	for k, v in ipairs(config.Get("owner_steamid_extra")) do
		if (v == player:SteamID()) then
			player:SetUserGroup("owner")
		end
	end

	ServerLog(player:Name().." ("..player:GetUserGroup()..") has connected to the server.")
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
	if (!player:HasPermission("spawn_objects")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnObject", player, model, skin) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnNPC(player, npc, weapon)
	if (!player:HasPermission("spawn_npc")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnNPC", player, npc, weapon) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnEffect(player, model)
	if (!player:HasPermission("spawn_effects")) then
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
	if (!player:HasPermission("spawn_swep")) then
		return false
	end

	if (hook.Run("FLPlayerSpawnSWEP", player, weapon, swep) == false) then
		return false
	end

	return true
end

function GM:PlayerSpawnSENT(player, class)
	if (!player:HasPermission("spawn_sent")) then
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
	if (!player:HasPermission("spawn_swep")) then
		return false
	end

	if (hook.Run("FLPlayerGiveSWEP", player, weapon, swep) == false) then
		return false
	end

	return true
end

function GM:EntityTakeDamage(ent, damageInfo)
	if (IsValid(ent) and ent:IsPlayer()) then
		hook.Run("PlayerTakeDamage", ent, damageInfo)
	end
end

function GM:PlayerTakeDamage(player, damageInfo)
	netstream.Start(player, "PlayerTakeDamage")
end

function GM:OnActiveCharacterSet(player, character)
	player:Spawn()
	player:SetModel(character.model or "models/humans/group01/male_02.mdl")

	hook.Run("PostCharacterLoaded", player, character)
end

function GM:PostCharacterLoaded(player, character)
	netstream.Start(player, "PostCharacterLoaded", character.uniqueID)

	player:CheckInventory()

	for slot, ids in ipairs(player:GetInventory()) do
		for k, v in ipairs(ids) do
			item.NetworkItem(player, v)
		end
	end
end

function GM:OneSecond()
	local curTime = CurTime()
	local sysTime = SysTime()

	if (!fl.nextSaveData) then
		fl.nextSaveData = curTime + 10
	elseif (fl.nextSaveData <= curTime) then
		if (hook.Run("FLShouldSaveData") != false) then
			fl.core:DevPrint("Saving framework's data...")
			hook.Run("FLSaveData")
		end

		fl.nextSaveData = curTime + config.Get("data_save_interval")
	end

	for k, v in pairs(areas.GetAll()) do
		if (istable(v.polys) and isstring(v.type)) then
			for k2, v2 in ipairs(v.polys) do
				for plyID, player in ipairs(_player.GetAll()) do
					player.lastArea = player.lastArea or {}
					player.lastArea[v.uniqueID] = player.lastArea[v.uniqueID] or {}
					local pos = player:GetPos()

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
				fl.core:DevPrint("Server is empty, restarting...")
				RunConsoleCommand("changelevel", game.GetMap())
			end
		end
	end
end

function GM:FLSaveData()
	item.SaveAll()

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

	function GM:PlayerPostThink(player)
		local curTime = CurTime()

		if ((player.flNextThink or 0) <= curTime) then
			hook.Call("PlayerThink", self, player, curTime)
			player.flNextThink = curTime + thinkDelay
		end

		if ((player.flNextSecond or 0) <= curTime) then
			hook.Call("PlayerOneSecond", self, player, curTime)
			player.flNextSecond = curTime + secondDelay
		end
	end
end