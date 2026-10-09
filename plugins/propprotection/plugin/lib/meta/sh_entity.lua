--- Entity extensions of the Prop Protection plugin: which character an entity belongs to.
-- The owner of an entity is networked to everyone, so the getters work on the server and on
-- the client; the ownership itself can only be changed on the server.
--
-- The file also provides the Common Prop Protection Interface (CPPI) that addons use to
-- ask any prop protection the same questions: the `CPPI` table and the `CPPI` methods of
-- entities and players are thin wrappers over `Entity:get_prop_owner`,
-- `Entity:set_prop_owner` and `PropProtection:can_manipulate`. Friends are not a concept of
-- the plugin, so `Player:CPPIGetFriends` always returns an empty list.

local ent_meta = FindMetaTable('Entity')
local player_meta = FindMetaTable('Player')

CPPI = CPPI or {}
CPPI_DEFER = CPPI_DEFER or 1e8
CPPI_NOTIMPLEMENTED = CPPI_NOTIMPLEMENTED or 1e9

--- Returns the name of the prop protection, as the CPPI asks for it.
-- @return [String]
function CPPI:GetName()
  return 'Flux Prop Protection'
end

--- Returns the version of the prop protection, as the CPPI asks for it.
-- @return [String]
function CPPI:GetVersion()
  return '1.0'
end

--- Returns the version of the CPPI that is implemented.
-- @return [Number]
function CPPI:GetInterfaceVersion()
  return 1.3
end

--- Returns the owner of the entity, as the CPPI asks for it.
-- @return [Player the owner, or nil if the entity belongs to nobody or its owner is not
--   connected on the character that owns it; String the ownership key as the unique ID of
--   the owner, nil if the entity belongs to nobody]
function ent_meta:CPPIGetOwner()
  local key = self:get_nv('fl_prop_owner')

  if !key then return end

  return PropProtection:find_owner(key), key
end

--- Checks whether a player may pick the entity up with the physics gun, as the CPPI asks
-- for it.
-- @param actor [Player]
-- @return [Boolean]
function ent_meta:CPPICanPhysgun(actor)
  return PropProtection:can_manipulate(actor, self, 'physgun') and true or false
end

--- Checks whether a player may use a tool on the entity, as the CPPI asks for it.
-- @param actor [Player]
-- @param tool [String tool ID]
-- @return [Boolean]
function ent_meta:CPPICanTool(actor, tool)
  return PropProtection:can_manipulate(actor, self, 'tool', tool) and true or false
end

--- Checks whether a player may use a property of the context menu on the entity, as the
-- CPPI asks for it.
-- @param actor [Player]
-- @param property [String property name]
-- @return [Boolean]
function ent_meta:CPPICanProperty(actor, property)
  return PropProtection:can_manipulate(actor, self, 'property', property) and true or false
end

--- Checks whether a player may drive the entity, as the CPPI asks for it.
-- @param actor [Player]
-- @return [Boolean]
function ent_meta:CPPICanDrive(actor)
  return PropProtection:can_manipulate(actor, self, 'drive') and true or false
end

--- Returns the friends of the player, as the CPPI asks for it. The plugin has no friends,
-- so the list is always empty.
-- @return [List<Player> an empty list]
function player_meta:CPPIGetFriends()
  return {}
end

--- Returns the key of the character the entity belongs to.
-- @return [String ownership key, see PropProtection:get_key; nil if the entity belongs to
--   nobody]
function ent_meta:get_prop_owner_key()
  return self:get_nv('fl_prop_owner')
end

--- Returns the player the entity belongs to.
-- @return [Player the owner, or nil if the entity belongs to nobody or its owner is not
--   connected on the character that owns it]
function ent_meta:get_prop_owner()
  return PropProtection:find_owner(self:get_nv('fl_prop_owner'))
end

--- Checks whether the entity belongs to the active character of a player.
-- ```
-- if entity:is_prop_owner(actor) then
--   entity:Remove()
-- end
-- ```
-- @param target [Player]
-- @return [Boolean]
function ent_meta:is_prop_owner(target)
  local key = self:get_nv('fl_prop_owner')

  return key != nil and key == PropProtection:get_key(target)
end

if SERVER then
  --- Gives the entity to the active character of a player, or to nobody. Server only.
  -- @param target=nil [Player the new owner; the entity is released when nil]
  -- @param permanent=nil [Boolean true to keep the entity when its owner leaves]
  -- @return [Boolean true if the entity now belongs to the player or, when it was released,
  --   if it had an owner]
  -- @see [PropProtection#give_ownership]
  -- @see [PropProtection#take_ownership]
  function ent_meta:set_prop_owner(target, permanent)
    if IsValid(target) then
      return PropProtection:give_ownership(target, self, permanent)
    end

    return PropProtection:take_ownership(self)
  end

  --- Gives the entity to the active character of a player, as the CPPI asks for it.
  -- Server only.
  -- @param owner=nil [Player the new owner; the entity is released when nil]
  -- @return [Boolean true if the entity now belongs to the player or, when it was released,
  --   if it had an owner]
  -- @see [Entity#set_prop_owner]
  function ent_meta:CPPISetOwner(owner)
    return self:set_prop_owner(owner)
  end
end
