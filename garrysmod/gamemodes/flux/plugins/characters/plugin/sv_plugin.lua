--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

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
	self:SaveCharacter()
end

function playerMeta:SetCharacterData(key, value)
	local charData = self:GetCharacterVar("data", {})

	charData[key] = value

	self:SetCharacterVar("data", charData)
end

function playerMeta:SaveCharacter()
	local char = self:GetCharacter()

	if (char) then
		character.Save(self, char.uniqueID)
	end
end