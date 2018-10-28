local player_meta = FindMetaTable('Player')

function player_meta:SaveUsergroup()
  if self.record then
    self.record.name = self:Name()
    self.record.role = self:GetUserGroup()
    self.record:save()
  end
end

function player_meta:SetPermissions(permTable)
  self:set_nv('permissions', permTable)
end

function player_meta:SetUserGroup(group)
  group = group or 'user'

  local group_obj = fl.admin:FindGroup(group)
  local old_group_obj = fl.admin:FindGroup(self:GetUserGroup())

  self:set_nv('role', group)

  if old_group_obj and group_obj and old_group_obj:OnGroupTake(self, group_obj) == nil then
    if group_obj:OnGroupSet(self, old_group_obj) == nil then
      self:SaveUsergroup()
    end
  end
end

function player_meta:SetCustomPermissions(data)
  self:set_nv('permissions', data)
end

function player_meta:RunCommand(cmd)
  return fl.command:Interpret(self, cmd)
end
