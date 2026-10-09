--- Entity extension of the Ragdoll plugin: finding the player a ragdoll belongs to.
-- @module [Entity]

local entity_meta = FindMetaTable('Entity')

--- Returns the player this entity is the ragdoll of. A corpse stops belonging to its player
-- once they respawn or leave the server.
-- @return [Player the owner, or nil if the entity is not the ragdoll of a player]
function entity_meta:get_ragdoll_owner()
  if SERVER then
    local owner = self.player

    if IsValid(owner) and owner:IsPlayer() and owner:GetDTEntity(ENT_RAGDOLL) == self then
      return owner
    end

    return
  end

  for k, v in player.Iterator() do
    if v:GetDTEntity(ENT_RAGDOLL) == self then
      return v
    end
  end
end
