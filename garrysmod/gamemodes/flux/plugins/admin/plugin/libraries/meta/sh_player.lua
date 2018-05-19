--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local player_meta = FindMetaTable("Player")

function player_meta:GetPermissions()
	return self:GetNetVar("flPermissions", {})
end

function player_meta:GetUserGroup()
	return self:GetNetVar("flUserGroup", "user")
end

function player_meta:GetSecondaryGroups()
	return self:GetNetVar("flSecondaryGroups", {})
end

function player_meta:GetCustomPermissions()
	return self:GetNetVar("flCustomPermissions", {})
end

function player_meta:IsSuperAdmin()
	if (self:IsRoot()) then return true end

	return self:IsMemberOf("superadmin")
end

function player_meta:IsAdmin()
	if (self:IsSuperAdmin()) then
		return true
	end

	return self:IsMemberOf("admin")
end

function player_meta:IsOperator()
	if (self:IsAdmin()) then
		return true
	end

	return self:IsMemberOf("operator")
end
