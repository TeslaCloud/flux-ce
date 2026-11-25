--- Shared hooks of the Ragdoll plugin: the data table variables of the player that hold
-- their ragdoll state and their ragdoll.

--- Registers the RagdollState and RagdollEntity data table variables on the player.
-- @param target [Player]
function Ragdoll:PlayerSetupDataTables(target)
  target:DTVar('Int', INT_RAGDOLL_STATE, 'RagdollState')
  target:DTVar('Entity', ENT_RAGDOLL, 'RagdollEntity')
end
