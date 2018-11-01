function PLUGIN:PlayerDeath(player)
  player:set_ragdoll_state(RAGDOLL_DUMMY)
end

function PLUGIN:PlayerSpawn(player)
  player:set_ragdoll_state(RAGDOLL_NONE)
end
