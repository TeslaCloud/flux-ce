class "Role"

Role.name = "Undefined"
Role.description = "Undefined"
Role.color = Color(255, 255, 255)
Role.icon = "icon16/user.png"
Role.immunity = 0
Role.protected = false
Role.permissions = {}
Role.base = nil

function Role:Role(id)
  self.id = id:to_id()
end

function Role:register()
  fl.admin:CreateGroup(self.id, self)
end

-- Called when player's primary group is being set to this group.
function Role:OnGroupSet(player, oldGroup) end

-- Called when player's primary group is taken or modified.
function Role:OnGroupTake(player, newGroup) end

-- Called when player is being added to this group as secondary group.
function Role:OnGroupAdd(player, secondaryGroups) end

-- Called when player is being removed from this group as secondary group.
function Role:OnGroupRemove(player) end

Role.SetParent = Role.set_base

function Role:GetID()
  return self.id
end

function Role:get_name()
  return self.name or "Unknown"
end

function Role:get_description()
  return self.description or "This group has no description"
end

function Role:GetColor()
  return self.color or Color("white")
end

function Role:GetImmunity()
  return self.immunity or 0
end

function Role:GetIsProtected()
  return self.protected or false
end

function Role:GetPermissions()
  return self.permissions or {}
end

function Role:GetIcon()
  return self.icon or "icon16/user.png"
end

function Role:GetBase()
  return self.base or nil
end

function Role:__tostring()
  return "User Group ["..self:GetID().."]["..self:get_name().."]"
end

Role.GetParent = Role.GetBase
