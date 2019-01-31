local player_meta = FindMetaTable('Player')

-- Implement common admin interfaces.
function player_meta:GetUserGroup()
  return self:get_role()
end

function player_meta:IsSuperAdmin()
  if self:is_root() then return true end

  return self:can 'administrate'
end

function player_meta:IsAdmin()
  if self:IsSuperAdmin() then
    return true
  end

  return self:can 'moderate'
end

function player_meta:get_role()
  return self:get_nv('role', 'user')
end

function player_meta:get_permissions()
  return self:get_nv('permissions', {})
end

function player_meta:get_permission(perm)
  return self:get_nv('permissions', {})[perm] or PERM_NO
end

function player_meta:is_assistant()
  if self:IsAdmin() then
    return true
  end

  return self:can 'staff'
end
