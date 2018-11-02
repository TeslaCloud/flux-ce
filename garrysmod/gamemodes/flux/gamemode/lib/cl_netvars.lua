if netvars then return end

library.new 'netvars'

local stored = netvars.stored or {}
local globals = netvars.globals or {}
netvars.stored = stored
netvars.globals = globals

local ent_meta = FindMetaTable('Entity')

-- A function to get a networked global.
function netvars.get_nv(key, default)
  if globals[key] != nil then
    return globals[key]
  end

  return default
end

-- Cannot set them on client.
function netvars.set_nv() end

-- A function to get entity's networked variable.
function ent_meta:get_nv(key, default)
  local index = self:EntIndex()

  if stored[index] and stored[index][key] != nil then
    return stored[index][key]
  end

  return default
end

-- Called from the server to set global networked variables.
cable.receive('fl_netvar_global_set', function(key, value)
  if key and value != nil then
    globals[key] = value
  end
end)

-- Called from the server to set entity's networked variable.
cable.receive('fl_netvar_set', function(ent_idx, key, value)
  if key and value != nil then
    stored[ent_idx] = stored[ent_idx] or {}
    stored[ent_idx][key] = value
  end
end)

-- Called from the server to delete entity from networked table.
cable.receive('fl_netvar_delete', function(ent_idx)
  stored[ent_idx] = nil
end)
