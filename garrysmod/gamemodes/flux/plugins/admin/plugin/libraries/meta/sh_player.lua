--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

function playerMeta:GetPermissions()
	return self:GetNetVar("flPermissions", {})
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