--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

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

if (SERVER) then
	function playerMeta:SetPermissions(permTable)
		self:SetNetVar("flPermissions", permTable)
	end

	function playerMeta:SetUserGroup(group)
		group = group or "user"

		self:SetNetVar("flUserGroup", group)
		fl.admin:CompilePermissions(self)
	end

	function playerMeta:SetSecondaryGroups(groups)
		self:SetNetVar("flSecondaryGroups", groups)
		fl.admin:CompilePermissions(self)
	end

	function playerMeta:AddSecondaryGroup(group)
		if (group == "owner" or group == "") then return end

		local groups = self:GetSecondaryGroups()

		table.insert(groups, group)

		self:SetNetVar("flSecondaryGroups", groups)
		fl.admin:CompilePermissions(self)
	end

	function playerMeta:RemoveSecondaryGroup(group)
		local groups = self:GetSecondaryGroups()

		for k, v in ipairs(groups) do
			if (v == group) then
				table.remove(groups, k)
				break
			end
		end

		self:SetNetVar("flSecondaryGroups", groups)
		fl.admin:CompilePermissions(self)
	end

	function playerMeta:SetCustomPermissions(data)
		self:SetNetVar("flCustomPermissions", data)
		fl.admin:CompilePermissions(self)
	end
end