--- Client side of ActiveNetwork: stores the global and per-entity variables received from the
-- server and provides the getters for them. Variables cannot be set on the client.
-- The server sets a global with the `fl_netvar_global_set` message and a variable of an
-- entity with `fl_netvar_set`, and makes the client forget all variables of an entity with
-- `fl_netvar_delete`. Every change that these messages make runs the `GlobalNetVarChanged`
-- or the `NetVarChanged` hook, so that client code can react to it without polling the
-- getters. A private variable only ever arrives on the clients of its recipients, where it
-- is read like any other.

if ActiveNetwork then return end

mod 'ActiveNetwork'

local stored = ActiveNetwork.stored or {}
local globals = ActiveNetwork.globals or {}
ActiveNetwork.stored = stored
ActiveNetwork.globals = globals

local ent_meta = FindMetaTable('Entity')

--- Checks whether a received value has to be reported as a change. Tables are decoded anew
-- every time they arrive and the server sends them again when their contents change, so
-- a table always counts as changed.
-- @param old_value [Any value held before the message]
-- @param new_value [Any value received]
-- @return [Boolean true if the hooks should run]
local function has_changed(old_value, new_value)
  return istable(new_value) or old_value != new_value
end

--- Runs the `NetVarChanged` hook for a variable of an entity.
-- @param ent_idx [Number index of the entity the variable belongs to]
-- @param key [String variable name]
-- @param old_value [Any previous value, nil if the variable was not set]
-- @param new_value [Any new value, nil if the variable has been unset]
local function run_changed_hook(ent_idx, key, old_value, new_value)
  --- Called on the client when the server has changed a networked variable of an entity,
  -- after the new value has been stored, so `Entity:get_nv` already returns it. Runs when
  -- a variable is set, when it is unset and, once for every variable the entity had, when
  -- the server clears the variables of an entity (which it does as the entity is removed).
  -- Does not run if a value that is not a table arrives unchanged; a table runs the hook
  -- every time it arrives. Variables are stored by entity index and may arrive before
  -- the entity does, or after it is gone, so the entity is not always valid.
  -- ```
  -- function PLUGIN:NetVarChanged(entity, key, old_value, new_value)
  --   if entity == PLAYER and key == 'faction' then
  --     self:rebuild_menu()
  --   end
  -- end
  -- ```
  -- @param entity [Entity The entity the variable belongs to; a NULL entity if the client
  --   does not have an entity with that index]
  -- @param key [String Variable name]
  -- @param old_value [Any Previous value, nil if the variable was not set]
  -- @param new_value [Any New value, nil if the variable has been unset]
  -- @param ent_idx [Number Index of the entity, which is known even if the entity is not]
  hook.Run('NetVarChanged', Entity(ent_idx), key, old_value, new_value, ent_idx)
end

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

Cable.receive('fl_netvar_global_set', function(key, value)
  if key then
    local old_value = globals[key]

    globals[key] = value

    if has_changed(old_value, value) then
      --- Called on the client when the server has changed a networked global variable,
      -- after the new value has been stored, so `ActiveNetwork.get_nv` already returns it.
      -- Does not run if a value that is not a table arrives unchanged; a table runs the
      -- hook every time it arrives.
      -- @param key [String Variable name]
      -- @param old_value [Any Previous value, nil if the variable was not set]
      -- @param new_value [Any New value, nil if the variable has been unset]
      hook.Run('GlobalNetVarChanged', key, old_value, value)
    end
  end
end)

Cable.receive('fl_netvar_set', function(ent_idx, key, value)
  if key then
    local vars = stored[ent_idx] or {}
    local old_value = vars[key]

    stored[ent_idx] = vars
    vars[key] = value

    if has_changed(old_value, value) then
      run_changed_hook(ent_idx, key, old_value, value)
    end
  end
end)

Cable.receive('fl_netvar_delete', function(ent_idx)
  local vars = stored[ent_idx]

  stored[ent_idx] = nil

  if vars then
    for key, old_value in pairs(vars) do
      run_changed_hook(ent_idx, key, old_value, nil)
    end
  end
end)
