--- Server-side entity extension of the Pickup Objects plugin: who is holding an entity.
-- @module [Entity]

local ent_meta = FindMetaTable('Entity')

--- Returns the player who is carrying or dragging this entity with their hands.
-- Serverside only. Entities held with the physics gun or the gravity gun have no holder.
-- @return [Player the holder, or nil if nobody holds the entity]
function ent_meta:get_holder()
  local holder = self.pickup_holder
  local data = holder and PickupObjects.holds[holder]

  if data and data.entity == self and IsValid(holder) then
    return holder
  end
end
