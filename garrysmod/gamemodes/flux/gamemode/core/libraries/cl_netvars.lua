--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]if (netvars) then return end

library.New "netvars"

local stored = netvars.stored or {}
local globals = netvars.globals or {}
netvars.stored = stored
netvars.globals = globals

local ent_meta = FindMetaTable("Entity")

-- A function to get a networked global.
function netvars.GetNetVar(key, default)
  if (globals[key] != nil) then
    return globals[key]
  end

  return default
end

-- Cannot set them on client.
function netvars.SetNetVar() end

-- A function to get entity's networked variable.
function ent_meta:GetNetVar(key, default)
  local index = self:EntIndex()

  if (stored[index] and stored[index][key] != nil) then
    return stored[index][key]
  end

  return default
end

-- Called from the server to set global networked variables.
netstream.Hook("set_global_netvar", function(key, value)
  if (key and value != nil) then
    globals[key] = value
  end
end)

-- Called from the server to set entity's networked variable.
netstream.Hook("set_netvar", function(entIdx, key, value)
  if (key and value != nil) then
    stored[entIdx] = stored[entIdx] or {}
    stored[entIdx][key] = value
  end
end)

-- Called from the server to delete entity from networked table.
netstream.Hook("delete_netvar", function(entIdx)
  stored[entIdx] = nil
end)
