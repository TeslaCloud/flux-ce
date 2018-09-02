local player_meta = FindMetaTable("Player")

function player_meta:SaveUsergroup()
  if self.record then
    self.record.name = self:Name()
    self.record.role = self:GetUserGroup()
    self.record:save()
  end
end

function player_meta:SetPermissions(permTable)
  self:set_nv("permissions", permTable)
end

function player_meta:SetUserGroup(group)
  group = group or "user"

  local groupObj = fl.admin:FindGroup(group)
  local oldGroupObj = fl.admin:FindGroup(self:GetUserGroup())

  self:set_nv("role", group)

  if (oldGroupObj and groupObj and oldGroupObj:OnGroupTake(self, groupObj) == nil) then
    if (groupObj:OnGroupSet(self, oldGroupObj) == nil) then
      self:SaveUsergroup()
    end
  end

  fl.admin:CompilePermissions(self)
end

function player_meta:SetSecondaryGroups(groups)
  self:set_nv("roles", groups)

  fl.admin:CompilePermissions(self)
end

function player_meta:AddSecondaryGroup(group)
  if (group == "root" or group == "") then return end

  local groups = self:get_roles()

  table.insert(groups, group)

  self:set_nv("roles", groups)

  fl.admin:CompilePermissions(self)
end

function player_meta:RemoveSecondaryGroup(group)
  local groups = self:get_roles()

  for k, v in ipairs(groups) do
    if (v == group) then
      table.remove(groups, k)

      break
    end
  end

  self:set_nv("roles", groups)

  fl.admin:CompilePermissions(self)
end

function player_meta:SetCustomPermissions(data)
  self:set_nv("permissions", data)

  fl.admin:CompilePermissions(self)
end

function player_meta:RunCommand(cmd)
  return fl.command:Interpret(self, cmd)
end
