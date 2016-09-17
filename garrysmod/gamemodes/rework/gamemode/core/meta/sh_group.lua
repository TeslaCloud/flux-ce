--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

Meta "Group";

Group.m_Name = "Undefined";
Group.m_Description = "Undefined";
Group.m_Color = Color(255, 255, 255);
Group.m_Icon = "icon16/user.png";
Group.m_Immunity = 0;
Group.m_IsProtected = false;
Group.m_Permissions = {};
Group.m_Base = nil;

function Group:Group(id)
	self.m_uniqueID = id;
end;

function Group:Register()
	rw.admin:CreateGroup(self.m_uniqueID, self);
end;

-- Called when player's primary group is being set to this group.
function Group:OnGroupSet(player, oldGroup) end;

-- Called when player's primary group is taken or modified.
function Group:OnGroupTake(player, newGroup) end;

-- Called when player is being added to this group as secondary group.
function Group:OnGroupAdd(player, secondaryGroups) end;

-- Called when player is being removed from this group as secondary group.
function Group:OnGroupRemove(player) end;

function Group:SetName(name)
	self.m_Name = name;
end;

function Group:SetDescription(desc)
	self.m_Description = desc;
end;

function Group:SetColor(col)
	self.m_Color = col;
end;

function Group:SetImmunity(immunity)
	self.m_Immunity = immunity;
end;

function Group:SetIsProtected(bIsProtected)
	self.m_IsProtected = bIsProtected;
end;

function Group:SetPermissions(permissionsTable)
	self.m_Permissions = permissionsTable;
end;

function Group:SetIcon(icon)
	self.m_Icon = icon;
end;

function Group:SetBase(base)
	self.m_Base = base;
end;

Group.SetParent = Group.SetBase;

function Group:GetID()
	return self.m_uniqueID;
end;

function Group:GetName()
	return self.m_Name or "Unknown";
end;

function Group:GetDescription()
	return self.m_Description or "This group has no description";
end;

function Group:GetColor()
	return self.m_Color or Color("white");
end;

function Group:GetImmunity()
	return self.m_Immunity or 0;
end;

function Group:GetIsProtected()
	return self.m_IsProtected or false;
end;

function Group:GetPermissions()
	return self.m_Permissions or {};
end;

function Group:GetIcon()
	return self.m_Icon or "icon16/user.png";
end;

function Group:GetBase()
	return self.m_Base or nil;
end;

Group.GetParent = Group.GetBase;