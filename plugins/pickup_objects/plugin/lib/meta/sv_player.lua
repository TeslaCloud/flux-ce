--- Server-side player extensions of the Pickup Objects plugin: what a player holds in their
-- hands and who is dragging their ragdoll.
-- @module [Player]

local player_meta = FindMetaTable('Player')

--- Returns the entity the player is carrying or dragging with their hands.
-- Serverside only.
-- @return [Entity the held entity, or nil if the player holds nothing]
function player_meta:get_holding_entity()
  local data = PickupObjects.holds[self]

  if data and IsValid(data.entity) then
    return data.entity
  end
end

--- Returns the player who is dragging the ragdoll of this player.
-- Serverside only. A ragdoll that is carried like any other object, with the
-- pickup_drag_ragdolls config turned off, does not count.
-- @return [Player the dragging player; nil if the player has no ragdoll, nobody drags it or
--   the Ragdoll plugin is not loaded]
function player_meta:get_dragger()
  if !self.get_ragdoll_entity then return end

  local ragdoll = self:get_ragdoll_entity()

  if !IsValid(ragdoll) then return end

  local holder = ragdoll:get_holder()

  if holder and PickupObjects.holds[holder].drag then
    return holder
  end
end
