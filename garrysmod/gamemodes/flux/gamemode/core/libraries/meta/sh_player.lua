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

function playerMeta:Name(bForceTrueName)
	return (!bForceTrueName and self.nameOverride) or self:GetNetVar("name", self:flName())
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
	Admin system
--]]

function playerMeta:HasPermission(perm)
	return hook.Run("PlayerHasPermission", self, perm)
end

function playerMeta:IsRoot()
	return hook.Run("PlayerIsRoot", self)
end

function playerMeta:IsMemberOf(group)
	if (self:GetUserGroup() == group) then
		return true
	end

	return hook.Run("PlayerIsMemberOfGroup", self, group)
end

