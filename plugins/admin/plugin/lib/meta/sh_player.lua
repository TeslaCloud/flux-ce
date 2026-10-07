local player_meta = FindMetaTable('Player')

-- Implement common admin interfaces.

--- Checks whether the player is a super admin: a root player or anyone with the
-- 'administrate' permission.
-- @return [Boolean]
function player_meta:is_super_admin()
  if self:is_root() then return true end

  return self:can 'administrate'
end

--- Checks whether the player is an admin: a super admin or anyone with the 'moderate'
-- permission.
-- @return [Boolean]
function player_meta:is_admin()
  if self:is_super_admin() then
    return true
  end

  return self:can 'moderate'
end

--- Returns the ID of the player's role.
-- @return [String role ID, 'user' if none has been set]
function player_meta:get_role()
  return self:get_nv('role', 'user')
end

--- Returns the player's role object.
-- @return [Role the role, or an empty table if it is not registered]
function player_meta:get_role_table()
  return Bolt:find_group(self:get_role()) or {}
end

--- Checks whether the player has the 'staff' permission.
-- @return [Boolean]
function player_meta:is_staff()
  return self:can 'staff'
end

--- Overrides the engine method to return the player's Flux role ID.
-- @param self [Player]
-- @return [String role ID]
player_meta.GetUserGroup  = function(self) return self:get_role() end
--- Overrides the engine method so that other addons recognize Flux super admins.
-- @param self [Player]
-- @return [Boolean]
player_meta.IsSuperAdmin  = function(self) return self:is_super_admin() end
--- Overrides the engine method so that other addons recognize Flux admins.
-- @param self [Player]
-- @return [Boolean]
player_meta.IsAdmin       = function(self) return self:is_admin() end

--- Returns the permissions set on the player individually, not counting those of their role.
-- @return [Hash PERM_ values keyed by permission ID]
function player_meta:get_permissions()
  return self:get_nv('permissions', {})
end

--- Returns the value of one of the player's individual permissions.
-- @param perm [String permission ID]
-- @return [Number PERM_ value, PERM_NO if the permission is not set]
function player_meta:get_permission(perm)
  return self:get_permissions()[perm] or PERM_NO
end

--- Returns the player's temporary permissions.
-- @return [Hash tables with value and expires (unix timestamp) fields, keyed by permission ID]
function player_meta:get_temp_permissions()
  return self:get_nv('temp_permissions', {})
end

--- Returns one of the player's temporary permissions.
-- @param perm [String permission ID]
-- @return [Hash table with value (PERM_ value) and expires (unix timestamp), or nil if not set]
function player_meta:get_temp_permission(perm)
  return self:get_temp_permissions()[perm]
end

--- Checks whether the player is at least an assistant: an admin or anyone with the 'staff'
-- permission.
-- @return [Boolean]
function player_meta:is_assistant()
  if self:IsAdmin() then
    return true
  end

  return self:can 'staff'
end
