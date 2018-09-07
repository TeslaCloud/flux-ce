if netvars then return end

library.new "netvars"

local stored = netvars.stored or {}
local globals = netvars.globals or {}
netvars.stored = stored
netvars.globals = globals

local ent_meta = FindMetaTable("Entity")
local player_meta = FindMetaTable("Player")

-- A function to check if value's type cannot be serialized and print an error if it is so.
local function IsBadType(key, val)
  if isfunction(val) then
    ErrorNoHalt("Cannot store functions as NetVars! ("..key..")\n")

    return true
  end

  return false
end

-- A function to get a networked global.
function netvars.get_nv(key, default)
  if globals[key] != nil then
    return globals[key]
  end

  return default
end

-- A function to set a networked global.
function netvars.set_nv(key, value, send)
  if IsBadType(key, value) then return end
  if netvars.get_nv(key) == value then return end

  globals[key] = value

  netstream.Start(send, "set_global_netvar", key, value)
end

-- A function to send entity's networked variables to a player (or players).
function ent_meta:SendNetVar(key, recv)
  netstream.Start(recv, "set_netvar", self:EntIndex(), key, (stored[self] and stored[self][key]))
end

-- A function to get entity's networked variable.
function ent_meta:get_nv(key, default)
  if stored[self] and stored[self][key] != nil then
    return stored[self][key]
  end

  return default
end

-- A function to flush all entity's networked variables.
function ent_meta:ClearNetVars(recv)
  stored[self] = nil
  netstream.Start(recv, "delete_netvar", self:EntIndex())
end

-- A function to set entity's networked variable.
function ent_meta:set_nv(key, value, send)
  if IsBadType(key, value) then return end
  if !istable(value) and self:get_nv(key) == value then return end

  stored[self] = stored[self] or {}
  stored[self][key] = value

  self:SendNetVar(key, send)
end

-- A function to send all current networked globals and entities' variables
-- to a player.
function player_meta:SyncNetVars()
  for k, v in pairs(globals) do
    netstream.Start(self, "set_global_netvar", k, v)
  end

  for k, v in pairs(stored) do
    if IsValid(k) then
      for k2, v2 in pairs(v) do
        netstream.Start(self, "set_netvar", k:EntIndex(), k2, v2)
      end
    end
  end
end
