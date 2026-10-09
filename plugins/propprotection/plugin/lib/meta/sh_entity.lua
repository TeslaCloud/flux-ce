--- Entity extensions of the Prop Protection plugin: which character an entity belongs to.
-- The owner of an entity is networked to everyone, so the getters work on the server and on
-- the client; the ownership itself can only be changed on the server.

local ent_meta = FindMetaTable('Entity')

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
end
