function PLUGIN:PlayerDeath(player)
  player:SetRagdollState(RAGDOLL_DUMMY)
end

function PLUGIN:PlayerSpawn(player)
  player:SetRagdollState(RAGDOLL_NONE)
end
