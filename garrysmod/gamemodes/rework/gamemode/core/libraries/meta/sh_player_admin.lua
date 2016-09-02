--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local playerMeta = FindMetaTable("Player");

function playerMeta:HasPermission(perm)
	return rw.admin:HasPermission(self, perm);
end;

function playerMeta:GetPermissions()
	return self:GetNetVar("rePermissions", {});
end;

function playerMeta:IsOwner()
	return (rw.config:Get("owner_steamid") == self:SteamID());
end;

function playerMeta:IsCoOwner()
	return (rw.config:Get("owner_steamid") == self:SteamID());
end;

function playerMeta:GetUserGroup()
	return self:GetNetVar("rwUserGroup", "user");
end;

function playerMeta:GetSecondaryGroups()
	return self:GetNetVar("rwSecondaryGroups", {});
end;

function playerMeta:GetCustomPermissions()
	return self:GetNetVar("rwCustomPermissions", {});
end;

function playerMeta:IsMemberOf(group)
	if (self:GetUserGroup() == group) then
		return true;
	end;

	for k, v in ipairs(self:GetSecondaryGroups()) do
		if (v == group) then
			return true;
		end;
	end;

	return false;
end;

function playerMeta:IsSuperAdmin()
	if (self:IsOwner() or self:IsCoOwner()) then
		return true;
	end;

	return self:IsMemberOf("superadmin");
end;

function playerMeta:IsAdmin()
	if (self:IsSuperAdmin()) then
		return true;
	end;

	return self:IsMemberOf("admin");
end;

function playerMeta:IsOperator()
	if (self:IsAdmin()) then
		return true;
	end;

	return self:IsMemberOf("operator");
end;

if (SERVER) then
	function playerMeta:SetPermissions(permTable)
		self:SetNetVar("rePermissions", permTable);
	end;

	function playerMeta:SetUserGroup(group)
		group = group or "user";

		self:SetNetVar("rwUserGroup", group);
		rw.admin:CompilePermissions(self);
	end;

	function playerMeta:AddSecondaryGroup(group)
		if (group == "owner" or group == "") then return; end;

		local groups = self:GetSecondaryGroups();

		table.insert(groups, group);

		self:SetNetVar("rwSecondaryGroups", groups);
		rw.admin:CompilePermissions(self);
	end;

	function playerMeta:RemoveSecondaryGroup(group)
		local groups = self:GetSecondaryGroups();

		for k, v in ipairs(groups) do
			if (v == group) then
				table.remove(groups, k);
				break;
			end;
		end;

		self:SetNetVar("rwSecondaryGroups", groups);
		rw.admin:CompilePermissions(self);
	end;
end;