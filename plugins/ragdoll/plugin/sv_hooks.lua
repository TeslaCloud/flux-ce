function PLUGIN:PlayerDeath(player)
  player:reset_action()
  player:set_ragdoll_state(RAGDOLL_DUMMY)
end

function PLUGIN:PlayerSpawn(player)
  player:set_ragdoll_state(RAGDOLL_NONE)
end

function PLUGIN:PlayerThink(player)
  if !player:Alive() and player:is_ragdolled() then
    hook.run('PlayerDeathThink', player)
  end
end

function PLUGIN:EntityTakeDamage(entity, damage_info)
  if entity:IsRagdoll() and IsValid(entity.player) then
    local player = entity.player
    player:TakeDamageInfo(damage_info)
  end
end
