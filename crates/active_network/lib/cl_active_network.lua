if ActiveNetwork then return end

mod 'ActiveNetwork'

local stored = ActiveNetwork.stored or {}
local globals = ActiveNetwork.globals or {}
ActiveNetwork.stored = stored
ActiveNetwork.globals = globals

local ent_meta = FindMetaTable('Entity')

--- Returns the value of a networked global variable.
-- @param key [String variable name]
-- @param default=nil [Any value to return if the variable is not set]
-- @return [Any variable value, or default]
function ActiveNetwork.get_nv(key, default)
  if globals[key] != nil then
    return globals[key]
  end

  return default
end

--- Does nothing. Networked globals cannot be set on the client.
function ActiveNetwork.set_nv() end

--- Returns the value of this entity's networked variable.
-- @param key [String variable name]
-- @param default=nil [Any value to return if the variable is not set]
-- @return [Any variable value, or default]
function ent_meta:get_nv(key, default)
  local index = self:EntIndex()

  if stored[index] and stored[index][key] != nil then
    return stored[index][key]
  end

  return default
end

-- Called from the server to set global networked variables.
Cable.receive('fl_netvar_global_set', function(key, value)
  if key and value != nil then
    globals[key] = value
  end
end)

-- Called from the server to set entity's networked variable.
Cable.receive('fl_netvar_set', function(ent_idx, key, value)
  if key and value != nil then
    stored[ent_idx] = stored[ent_idx] or {}
    stored[ent_idx][key] = value
  end
end)

-- Called from the server to delete entity from networked table.
Cable.receive('fl_netvar_delete', function(ent_idx)
  stored[ent_idx] = nil
end)
