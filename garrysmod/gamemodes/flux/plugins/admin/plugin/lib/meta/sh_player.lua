local player_meta = FindMetaTable('Player')

-- Implement common admin interfaces.
function player_meta:is_super_admin()
  if self:is_root() then return true end

  return self:can 'administrate'
end

function player_meta:is_admin()
  if self:is_super_admin() then
    return true
  end

  return self:can 'moderate'
end

function player_meta:get_role()
  return self:get_nv('role', 'user')
end

player_meta.GetUserGroup  = function(self) return self:get_role() end
player_meta.IsSuperAdmin  = function(self) return self:is_super_admin() end
player_meta.IsAdmin       = function(self) return self:is_admin() end

function player_meta:get_permissions()
  return self:get_nv('permissions', {})
end

function player_meta:get_permission(perm)
  return self:get_permissions()[perm] or PERM_NO
end

function player_meta:get_temp_permissions()
  return self:get_nv('temp_permissions', {})
end

function player_meta:get_temp_permission(perm)
  return self:get_temp_permissions()[perm]
end

function player_meta:is_assistant()
  if self:IsAdmin() then
    return true
  end

  return self:can 'staff'
end
