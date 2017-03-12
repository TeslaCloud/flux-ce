--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

Class "CUserGroup"

CUserGroup.m_Name = "Undefined"
CUserGroup.m_Description = "Undefined"
CUserGroup.m_Color = Color(255, 255, 255)
CUserGroup.m_Icon = "icon16/user.png"
CUserGroup.m_Immunity = 0
CUserGroup.m_IsProtected = false
CUserGroup.m_Permissions = {}
CUserGroup.m_Base = nil

function CUserGroup:CUserGroup(id)
	self.m_uniqueID = id:MakeID()
end

function CUserGroup:Register()
	fl.admin:CreateGroup(self.m_uniqueID, self)
end

-- Called when player's primary group is being set to this group.
function CUserGroup:OnGroupSet(player, oldGroup) end

-- Called when player's primary group is taken or modified.
function CUserGroup:OnGroupTake(player, newGroup) end

-- Called when player is being added to this group as secondary group.
function CUserGroup:OnGroupAdd(player, secondaryGroups) end

-- Called when player is being removed from this group as secondary group.
function CUserGroup:OnGroupRemove(player) end

function CUserGroup:SetName(name)
	self.m_Name = name
end

function CUserGroup:SetDescription(desc)
	self.m_Description = desc
end

function CUserGroup:SetColor(col)
	self.m_Color = col
end

function CUserGroup:SetImmunity(immunity)
	self.m_Immunity = immunity
end

function CUserGroup:SetIsProtected(bIsProtected)
	self.m_IsProtected = bIsProtected
end

function CUserGroup:SetPermissions(permissionsTable)
	self.m_Permissions = permissionsTable
end

function CUserGroup:SetIcon(icon)
	self.m_Icon = icon
end

function CUserGroup:SetBase(base)
	self.m_Base = base
end

CUserGroup.SetParent = CUserGroup.SetBase

function CUserGroup:GetID()
	return self.m_uniqueID
end

function CUserGroup:GetName()
	return self.m_Name or "Unknown"
end

function CUserGroup:GetDescription()
	return self.m_Description or "This group has no description"
end

function CUserGroup:GetColor()
	return self.m_Color or Color("white")
end

function CUserGroup:GetImmunity()
	return self.m_Immunity or 0
end

function CUserGroup:GetIsProtected()
	return self.m_IsProtected or false
end

function CUserGroup:GetPermissions()
	return self.m_Permissions or {}
end

function CUserGroup:GetIcon()
	return self.m_Icon or "icon16/user.png"
end

function CUserGroup:GetBase()
	return self.m_Base or nil
end

function CUserGroup:__tostring()
	return "User Group ["..self:GetID().."]["..self:GetName().."]"
end

CUserGroup.GetParent = CUserGroup.GetBase

_G["Group"] = CUserGroup;