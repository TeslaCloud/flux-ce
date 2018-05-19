--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

class "CUserGroup"

CUserGroup.Name = "Undefined"
CUserGroup.Description = "Undefined"
CUserGroup.Color = Color(255, 255, 255)
CUserGroup.Icon = "icon16/user.png"
CUserGroup.Immunity = 0
CUserGroup.IsProtected = false
CUserGroup.Permissions = {}
CUserGroup.Base = nil

function CUserGroup:CUserGroup(id)
  self.id = id:MakeID()
end

function CUserGroup:Register()
  fl.admin:CreateGroup(self.id, self)
end

-- Called when player's primary group is being set to this group.
function CUserGroup:OnGroupSet(player, oldGroup) end

-- Called when player's primary group is taken or modified.
function CUserGroup:OnGroupTake(player, newGroup) end

-- Called when player is being added to this group as secondary group.
function CUserGroup:OnGroupAdd(player, secondaryGroups) end

-- Called when player is being removed from this group as secondary group.
function CUserGroup:OnGroupRemove(player) end

CUserGroup.SetParent = CUserGroup.SetBase

function CUserGroup:GetID()
  return self.id
end

function CUserGroup:GetName()
  return self.Name or "Unknown"
end

function CUserGroup:GetDescription()
  return self.Description or "This group has no description"
end

function CUserGroup:GetColor()
  return self.Color or Color("white")
end

function CUserGroup:GetImmunity()
  return self.Immunity or 0
end

function CUserGroup:GetIsProtected()
  return self.IsProtected or false
end

function CUserGroup:GetPermissions()
  return self.Permissions or {}
end

function CUserGroup:GetIcon()
  return self.Icon or "icon16/user.png"
end

function CUserGroup:GetBase()
  return self.Base or nil
end

function CUserGroup:__tostring()
  return "User Group ["..self:GetID().."]["..self:GetName().."]"
end

CUserGroup.GetParent = CUserGroup.GetBase

_G["Group"] = CUserGroup
