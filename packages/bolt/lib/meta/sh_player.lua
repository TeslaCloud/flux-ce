--- Player extensions of Bolt: the player's role, their individual and temporary permissions,
-- those of their active character, and the staff level checks. The engine's
-- `GetUserGroup`, `IsAdmin` and `IsSuperAdmin` are overridden so that other addons see Flux
-- roles and permissions. When Bolt defers to another admin mod (`bolt_external_admin`), the
-- overrides call the engine's own methods, and the role of a player is their usergroup.

local player_meta = FindMetaTable('Player')

player_meta.engine_get_user_group = player_meta.engine_get_user_group or player_meta.GetUserGroup
player_meta.engine_is_admin = player_meta.engine_is_admin or player_meta.IsAdmin
player_meta.engine_is_super_admin = player_meta.engine_is_super_admin or player_meta.IsSuperAdmin

--- Returned while a player has no character permissions, so that the permission checks do not
-- create a table every time. It is never written to.
local no_permissions = {}

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

--- Returns the ID of the player's role, which is the usergroup the engine has for them when
-- Bolt defers to another admin mod.
-- @return [String role ID, 'user' if none has been set]
function player_meta:get_role()
  if Bolt:uses_external_admin() then
    return self:engine_get_user_group()
  end

  return self:get_nv('role', 'user')
end

--- Returns the player's role object, see `Bolt:get_group_role`.
-- @return [Role the role, or an empty table if it is not registered]
function player_meta:get_role_table()
  return Bolt:get_group_role(self:get_role()) or {}
end

--- Checks whether the player has the 'staff' permission.
-- @return [Boolean]
function player_meta:is_staff()
  return self:can 'staff'
end

--- Overrides the engine method to return the player's Flux role ID.
-- @param self [Player]
-- @return [String role ID]
player_meta.GetUserGroup = self -> self:get_role()

--- Overrides the engine method so that other addons recognize Flux super admins. Calls the
-- engine's method when Bolt defers to another admin mod.
-- @return [Boolean]
function player_meta:IsSuperAdmin()
  if Bolt:uses_external_admin() then
    return self:engine_is_super_admin()
  end

  return self:is_super_admin()
end

--- Overrides the engine method so that other addons recognize Flux admins. Calls the
-- engine's method when Bolt defers to another admin mod.
-- @return [Boolean]
function player_meta:IsAdmin()
  if Bolt:uses_external_admin() then
    return self:engine_is_admin()
  end

  return self:is_admin()
end

--- Returns the permissions set on the player individually, not counting those of their role.
-- @return [Map PERM_ values keyed by permission ID]
function player_meta:get_permissions()
  return self:get_nv('permissions', {})
end

--- Returns the value of one of the player's individual permissions.
-- @param perm [String permission ID]
-- @return [Number PERM_ value, PERM_NO if the permission is not set]
function player_meta:get_permission(perm)
  local perms = self:get_nv('permissions')

  return perms and perms[perm] or PERM_NO
end

--- Returns the player's temporary permissions.
-- @return [Map tables with value and expires (unix timestamp) fields, keyed by permission ID]
function player_meta:get_temp_permissions()
  return self:get_nv('temp_permissions', {})
end

--- Returns one of the player's temporary permissions.
-- @param perm [String permission ID]
-- @return [Map table with value (PERM_ value) and expires (unix timestamp), or nil if not set]
function player_meta:get_temp_permission(perm)
  local perms = self:get_nv('temp_permissions')

  return perms and perms[perm]
end

--- Returns the permissions set on the player's active character, not counting those of the
-- player and of their role. They are networked to every client while the character is
-- loaded. The table is empty when no character is loaded; it must not be modified.
-- @return [Map PERM_ values keyed by permission ID]
function player_meta:get_character_permissions()
  return self:get_nv('character_permissions') or no_permissions
end

--- Returns the value of one of the permissions set on the player's active character.
-- @param perm [String permission ID]
-- @return [Number PERM_ value, PERM_NO if the permission is not set or no character is loaded]
function player_meta:get_character_permission(perm)
  local perms = self:get_nv('character_permissions')

  return perms and perms[perm] or PERM_NO
end

--- Returns the temporary permissions of the player's active character.
-- @return [Map tables with value and expires (unix timestamp) fields, keyed by permission ID;
--   empty when no character is loaded. The table must not be modified]
function player_meta:get_character_temp_permissions()
  return self:get_nv('character_temp_permissions') or no_permissions
end

--- Returns one of the temporary permissions of the player's active character.
-- @param perm [String permission ID]
-- @return [Map table with value (PERM_ value) and expires (unix timestamp), or nil if not set]
function player_meta:get_character_temp_permission(perm)
  local perms = self:get_nv('character_temp_permissions')

  return perms and perms[perm]
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
