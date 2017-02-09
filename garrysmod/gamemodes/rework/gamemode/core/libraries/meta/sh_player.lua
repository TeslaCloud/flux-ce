--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

if (SERVER) then
	function playerMeta:SetWhitelists(data)
		self:SetNetVar("whitelists", data)
		self:SavePlayer()
	end

	function playerMeta:GiveWhitelist(name)
		local whitelists = self:GetWhitelists()

		if (!table.HasValue(whitelists, name)) then
			table.insert(whitelists, name)
			self:SetWhitelists(whitelists)
		end
	end

	function playerMeta:TakeWhitelist(name)
		local whitelists = self:GetWhitelists()

		for k, v in ipairs(whitelists) do
			if (v == name) then
				table.remove(whitelists, k)
				break
			end
		end

		self:SetWhitelists(whitelists)
	end

	function playerMeta:SavePlayer()
		return rw.player:Save(self)
	end

	function playerMeta:SetData(data)
		self:SetNetVar("rwData", {})
	end

	function playerMeta:SetInitialized(bIsInitialized)
		if (bIsInitialized == nil) then bIsInitialized = true; end

		self:SetDTBool(BOOL_INITIALIZED, bIsInitialized)
	end

	function playerMeta:Notify(message)
		rw.player:Notify(self, message)
	end
end

function playerMeta:HasInitialized()
	return self:GetDTBool(BOOL_INITIALIZED) or false
end

function playerMeta:GetData()
	return self:GetNetVar("rwData", {})
end

function playerMeta:GetWhitelists()
	return self:GetNetVar("whitelists", {})
end

function playerMeta:HasWhitelist(name)
	return table.HasValue(self:GetWhitelists(), name)
end

playerMeta.rwName = playerMeta.rwName or playerMeta.Name

function playerMeta:Name()
	if (character) then
		return self.nameOverride or self:GetNetVar("name", self:rwName())
	end

	return self.nameOverride or self:rwName()
end

function playerMeta:SteamName()
	return self:rwName()
end

function playerMeta:SetModel(sPath)
	local oldModel = self:GetModel()

	hook.Run("PlayerModelChanged", self, sPath, oldModel)

	if (SERVER) then
		netstream.Start(nil, "PlayerModelChanged", self:EntIndex(), sPath, oldModel)
	end

	return self:rwSetModel(sPath)
end

--[[

	Characters System

--]]

function playerMeta:GetActiveCharacterID()
	return self:GetNetVar("ActiveCharacter", nil)
end

function playerMeta:GetCharacterKey()
	return self:GetNetVar("key", -1)
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

if (SERVER) then
	function playerMeta:SetActiveCharacter(id)
		local curChar = self:GetActiveCharacterID()

		if (curChar) then
			hook.Run("OnCharacterChange", self, self:GetCharacter(), id)
		end

		self:SetNetVar("ActiveCharacter", id)

		local charData = self:GetCharacter()

		self:SetNetVar("name", charData.name or self:SteamName())
		self:SetNetVar("physDesc", charData.physDesc or "")
		self:SetNetVar("gender", charData.gender or CHAR_GENDER_MALE)
		self:SetNetVar("faction", charData.faction or "player")
		self:SetNetVar("key", charData.key or -1)
		self:SetNetVar("model", charData.model or "models/humans/group01/male_02.mdl")
		self:SetNetVar("inventory", charData.inventory)
		hook.Run("OnActiveCharacterSet", self, self:GetCharacter())
	end

	function playerMeta:SetCharacterVar(id, val)
		if (isstring(id)) then
			self:SetNetVar(id, val)
			self:GetCharacter()[id] = val
		end
	end

	function playerMeta:SetInventory(newInv)
		if (!istable(newInv)) then return end
		self:SetCharacterVar("inventory", newInv)
	end

	function playerMeta:SetCharacterData(key, value)
		local charData = self:GetCharacterVar("data", {})

		charData[key] = value

		self:SetCharacterVar("data", charData)
	end

	function playerMeta:SaveCharacter()
		character.Save(self, self:GetCharacter().uniqueID)
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