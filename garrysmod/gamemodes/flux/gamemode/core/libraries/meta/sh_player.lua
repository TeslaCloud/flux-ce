--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

function playerMeta:HasInitialized()
	return self:GetDTBool(BOOL_INITIALIZED) or false
end

function playerMeta:GetData()
	return self:GetNetVar("flData", {})
end

function playerMeta:GetWhitelists()
	return self:GetNetVar("whitelists", {})
end

function playerMeta:HasWhitelist(name)
	return table.HasValue(self:GetWhitelists(), name)
end

playerMeta.flName = playerMeta.flName or playerMeta.Name

function playerMeta:Name(bForceSteamName)
	if (bForceSteamName) then return self:flName() end

	return self.nameOverride or self:GetNetVar("name", self:flName())
end

function playerMeta:SteamName()
	return self:flName()
end

function playerMeta:SetModel(sPath)
	local oldModel = self:GetModel()

	hook.Run("PlayerModelChanged", self, sPath, oldModel)

	if (SERVER) then
		netstream.Start(nil, "PlayerModelChanged", self:EntIndex(), sPath, oldModel)
	end

	return self:flSetModel(sPath)
end

--[[

	Characters System

--]]

-- See definition of playerMeta:GetCharacter in sh_character.lua library

function playerMeta:GetActiveCharacterID()
	return self:GetNetVar("ActiveCharacter", nil)
end

function playerMeta:GetCharacterKey()
	return self:GetNetVar("key", -1)
end

function playerMeta:CharacterLoaded()
	if (self:IsBot()) then return true end

	local id = self:GetActiveCharacterID()

	return id and id > 0
end

function playerMeta:GetInventory()
	return self:GetNetVar("inventory", {})
end

function playerMeta:GetPhysDesc()
	return self:GetNetVar("physDesc", "This character has no description!")
end

function playerMeta:GetCharacterVar(id, default)
	if (SERVER) then
		return self:GetCharacter()[id] or default
	else
		return self:GetNetVar(id, default)
	end
end

function playerMeta:GetCharacterData(key, default)
	return self:GetCharacterVar("data", {})[key] or default
end

--[[
	Factions system
--]]

function playerMeta:GetFactionID()
	return self:GetNetVar("faction", "player")
end

function playerMeta:GetFaction()
	return faction.FindByID(self:GetFactionID())
end

function playerMeta:GetRank()
	return self:GetCharacterData("Rank", -1)
end

function playerMeta:IsRank(strRank, bStrict)
	local factionTable = self:GetFaction()
	local rank = self:GetRank()

	if (rank != -1 and factionTable) then
		for k, v in ipairs(factionTable.Ranks) do
			if (string.utf8lower(v.uniqueID) == string.utf8lower(strRank)) then
				return (bStrict and k == rank) or k <= rank
			end
		end
	end

	return false
end

--[[
	Admin system
--]]

function playerMeta:HasPermission(perm)
	return fl.admin:HasPermission(self, perm)
end

function playerMeta:GetPermissions()
	return self:GetNetVar("flPermissions", {})
end

function playerMeta:IsOwner()
	return self:IsMemberOf("owner")
end

function playerMeta:IsCoOwner()
	if (self:IsOwner()) then
		return true
	end

	if (config.Get("owner_steamid_extra")) then
		for k, v in ipairs(config.Get("owner_steamid_extra")) do
			if (v == self:SteamID()) then
				return true
			end
		end
	end

	return false
end

function playerMeta:GetUserGroup()
	return self:GetNetVar("flUserGroup", "user")
end

function playerMeta:GetSecondaryGroups()
	return self:GetNetVar("flSecondaryGroups", {})
end

function playerMeta:GetCustomPermissions()
	return self:GetNetVar("flCustomPermissions", {})
end

function playerMeta:IsMemberOf(group)
	if (self:GetUserGroup() == group) then
		return true
	end

	for k, v in ipairs(self:GetSecondaryGroups()) do
		if (v == group) then
			return true
		end
	end

	return false
end

function playerMeta:IsSuperAdmin()
	if (self:IsOwner() or self:IsCoOwner()) then
		return true
	end

	return self:IsMemberOf("superadmin")
end

function playerMeta:IsAdmin()
	if (self:IsSuperAdmin()) then
		return true
	end

	return self:IsMemberOf("admin")
end

function playerMeta:IsOperator()
	if (self:IsAdmin()) then
		return true
	end

	return self:IsMemberOf("operator")
end

