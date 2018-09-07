local player_meta = FindMetaTable("Player")

function player_meta:get_role()
  return self:get_nv("role", "user")
end

function player_meta:GetPermissions()
  return self:get_nv("permissions", {})
end

function player_meta:GetCustomPermissions()
  return self:get_nv("permissions", {})
end

function player_meta:is_assistant()
  if self:IsAdmin() then
    return true
  end

  return self:has_group("assistant")
end

-- Implement common admin interfaces.
function player_meta:GetUserGroup()
  return self:get_role()
end

function player_meta:IsSuperAdmin()
  if self:is_root() then return true end

  return self:has_group("superadmin")
end

function player_meta:IsAdmin()
  if self:IsSuperAdmin() then
    return true
  end

  return self:has_group('moderator')
end
