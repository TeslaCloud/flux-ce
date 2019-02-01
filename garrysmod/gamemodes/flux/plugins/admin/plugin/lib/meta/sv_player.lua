local player_meta = FindMetaTable('Player')

function player_meta:SetUserGroup(group)
  group = group or 'user'

  local group_obj = Bolt:find_group(group)
  local old_group_obj = Bolt:find_group(self:GetUserGroup())

  self:set_nv('role', group)

  if old_group_obj and group_obj and old_group_obj:on_role_taken(self, group_obj) == nil then
    if group_obj:on_role_set(self, old_group_obj) == nil then
      self:save_usergroup()
    end
  end
end

function player_meta:save_usergroup()
  if self.record then
    self.record.name = self:name()
    self.record.role = self:GetUserGroup()
    self.record:save()
  end
end

function player_meta:set_permissions(perm_table)
  self:set_nv('permissions', perm_table)
end

function player_meta:set_permission(perm_id, value)
  local create = true

  if self.record.permissions then
    for k, v in pairs(self.record.permissions) do
      if v.permission_id == perm_id then
        create = false

        if value != PERM_NO then
          if value != v.object then
            v.object = value
            v:save()
          end
        else
          v:destroy()
        end
      end
    end
  end

  if create then
    local perm = Permission.new()
      perm.permission_id = perm_id
      perm.object = value
      perm.user_id = self.record.id
    perm:save()

    self.record.permissions[perm.id] = perm
  end

  local perm_table = self:get_permissions()

  perm_table[perm_id] = value != PERM_NO and value or nil

  self:set_permissions(perm_table)
end

function player_meta:run_command(cmd)
  return fl.command:interpret(self, cmd)
end
