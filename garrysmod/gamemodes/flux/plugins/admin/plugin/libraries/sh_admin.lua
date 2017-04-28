--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("admin", fl)
local groups = fl.admin.groups or {}			-- Usergroups data
local permissions = fl.admin.permissions or {}	-- Permission descriptions and other data
local players = fl.admin.players or {}			-- Compiled permissions for each player
fl.admin.groups = groups
fl.admin.permissions = permissions
fl.admin.players = players

local compilerCache = {}

function fl.admin:GetPermissions()
	return permissions
end

function fl.admin:GetGroups()
	return groups
end

function fl.admin:GetPlayers()
	return players
end

function fl.admin:CreateGroup(id, data)
	if (!isstring(id)) then return end

	data.m_UniqueID = id

	if (data.m_Base) then
		local parent = groups[data.m_Base]

		if (parent) then
			local parentCopy = table.Copy(parent)

			table.Merge(parentCopy.m_Permissions, data.m_Permissions)

			data.m_Permissions = parentCopy.m_Permissions

			for k, v in pairs(parentCopy) do
				if (k == "m_Permissions") then continue end

				if (!data[k]) then
					data[k] = v
				end
			end
		end
	end

	if (!groups[id]) then
		groups[id] = data
	end
end

function fl.admin:AddPermission(id, category, data, bForce)
	if (!id) then return end

	category = category or "general"
	data.uniqueID = id
	permissions[category] = permissions[category] or {}

	if (!permissions[category][id] or bForce) then
		permissions[category][id] = data
	end
end

function fl.admin:RegisterPermission(id, name, description, category)
	if (!isstring(id) or id == "") then return end

	local data = {}
		data.uniqueID = id:MakeID()
		data.description = description or "No description provided."
		data.category = category or "general"
		data.name = name or id
	self:AddPermission(id, category, data, true)
end

function fl.admin:PermissionFromCommand(cmdObj)
	if (!cmdObj) then return end

	self:RegisterPermission(cmdObj.uniqueID, cmdObj.name, cmdObj.description, cmdObj.category)
end

function fl.admin:CheckPermission(player, permission)
	local playerPermissions = players[player:SteamID()]

	if (playerPermissions) then
		return playerPermissions[permission]
	end
end

function fl.admin:GetPermissionsInCategory(category)
	local perms = {}

	if (category == "all") then
		for k, v in pairs(permissions) do
			for k2, v2 in pairs(v) do
				table.insert(perms, k2)
			end
		end
	else
		if (permissions[category]) then
			for k, v in pairs(permissions[category]) do
				table.insert(perms, k)
			end
		end
	end

	return perms
end

function fl.admin:IsCategory(id)
	if (id == "all" or permissions[id]) then
		return true
	end

	return false
end

function fl.admin:GetGroupPermissions(id)
	if (groups[id]) then
		return groups[id].m_Permissions
	else
		return {}
	end
end

function fl.admin:HasPermission(player, permission)
	if (!IsValid(player)) then return true end
	if (player:IsOwner()) then return true end
	if (player:IsCoOwner()) then return true end

	local steamID = player:SteamID()

	if (players[steamID] and (players[steamID][permission] or players[steamID]["all"])) then
		return true
	end

	local netPerms = player:GetNetVar("flPermissions", {})

	if (netPerms and netPerms[permission]) then
		return true
	end

	return false
end

function fl.admin:FindGroup(id)
	if (groups[id]) then
		return groups[id]
	end

	return nil
end

function fl.admin:GroupExists(id)
	return self:FindGroup(id)
end

function fl.admin:CheckImmunity(player, target, canBeEqual)
	if (!IsValid(player) or !IsValid(target)) then
		return true
	end

	local group1 = self:FindGroup(player:GetUserGroup())
	local group2 = self:FindGroup(target:GetUserGroup())

	if (!isnumber(group1.immunity) or !isnumber(group2.immunity)) then
		return true
	end

	if (group1.immunity > group2.immunity) then
		return true
	end

	if (canBeEqual and group1.immunity == group2.immunity) then
		return true
	end

	return false
end

pipeline.Register("group", function(uniqueID, fileName, pipe)
	GROUP = Group(uniqueID)

	util.Include(fileName)

	GROUP:Register() GROUP = nil
end)

function fl.admin:IncludeGroups(directory)
	pipeline.IncludeDirectory("group", directory)
end

if (SERVER) then
	local function SetPermission(steamID, permID, value)
		players[steamID] = players[steamID] or {}
		players[steamID][permID] = value
	end

	local function DeterminePermission(steamID, permID, value)
		local permTable = compilerCache[steamID]

		permTable[permID] = permTable[permID] or PERM_NO

		if (value == PERM_NO) then return end
		if (permTable[permID] == PERM_ALLOW_OVERRIDE) then return end

		if (value == PERM_ALLOW_OVERRIDE) then
			permTable[permID] = PERM_ALLOW_OVERRIDE
			SetPermission(steamID, permID, true)

			return
		end

		if (permTable[permID] == PERM_NEVER) then return end
		if (permTable[permID] == value) then return end

		if (value == PERM_NEVER) then
			permTable[permID] = PERM_NEVER
			SetPermission(steamID, permID, false)

			return
		elseif (value == PERM_ALLOW) then
			permTable[permID] = PERM_ALLOW
			SetPermission(steamID, permID, true)

			return
		end

		permTable[permID] = PERM_ERROR
		SetPermission(steamID, permID, false)
	end

	local function DetermineCategory(steamID, permID, value)
		if (fl.admin:IsCategory(permID)) then
			local catPermissions = fl.admin:GetPermissionsInCategory(permID)

			for k, v in ipairs(catPermissions) do
				DeterminePermission(steamID, v, value)
			end
		else
			DeterminePermission(steamID, permID, value)
		end
	end

	function fl.admin:CompilePermissions(player)
		if (!IsValid(player)) then return end

		local steamID = player:SteamID()
		local userGroup = player:GetUserGroup()
		local secondaryGroups = player:GetSecondaryGroups()
		local playerPermissions = player:GetCustomPermissions()
		local groupPermissions = self:GetGroupPermissions(userGroup)

		compilerCache[steamID] = {}

		for k, v in pairs(groupPermissions) do
			DetermineCategory(steamID, k, v)
		end

		for _, group in ipairs(secondaryGroups) do
			local permTable = self:GetGroupPermissions(group)

			for k, v in pairs(permTable) do
				DetermineCategory(steamID, k, v)
			end
		end

		for k, v in pairs(playerPermissions) do
			DetermineCategory(steamID, k, v)
		end

		local extras = {}

		hook.Run("OnPermissionsCompiled", player, extras)

		if (istable(extras)) then
			for id, extra in pairs(extras) do
				for k, v in pairs(extra) do
					DeterminePermissions(steamID, k, v)
				end
			end
		end

		player:SetPermissions(players[steamID])
		compilerCache[steamID] = nil
	end
end

do
	-- Flags
	fl.admin:RegisterPermission("physgun", "Access Physgun", "Grants access to the physics gun.", "flags")
	fl.admin:RegisterPermission("toolgun", "Access Tool Gun", "Grants access to the tool gun.", "flags")
	fl.admin:RegisterPermission("spawn_props", "Spawn Props", "Grants access to spawn props.", "flags")
	fl.admin:RegisterPermission("spawn_chairs", "Spawn Chairs", "Grants access to spawn chairs.", "flags")
	fl.admin:RegisterPermission("spawn_vehicles", "Spawn Vehicles", "Grants access to spawn vehicles.", "flags")
	fl.admin:RegisterPermission("spawn_entities", "Spawn All Entities", "Grants access to spawn any entity.", "flags")
	fl.admin:RegisterPermission("spawn_npcs", "Spawn NPCs", "Grants access to spawn NPCs.", "flags")
	fl.admin:RegisterPermission("spawn_ragdolls", "Spawn Ragdolls", "Grants access to spawn ragdolls.", "flags")
	fl.admin:RegisterPermission("spawn_sweps", "Spawn SWEPs", "Grants access to spawn scripted weapons.", "flags")
	fl.admin:RegisterPermission("physgun_freeze", "Freeze Protected Entities", "Grants access to freeze protected entities.", "flags")
	fl.admin:RegisterPermission("physgun_pickup", "Unlimited Physgun", "Grants access to pick up any entity with the physics gun.", "flags")

	-- General permissions
	fl.admin:RegisterPermission("context_menu", "Access Context Menu", "Grants access to the context menu.", "general")
end