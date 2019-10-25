function PLUGIN:PlayerDeath(player)
  local decay_time = math.max(Config.get('corpse_decay_time'), Config.get('respawn_delay'))

  local settings = {}
  settings.decay_time = decay_time

  player:reset_action()
  player:set_ragdoll_state(RAGDOLL_DUMMY, settings)
end

function PLUGIN:PlayerSpawn(player)
  player:set_ragdoll_state(RAGDOLL_NONE)
end

function PLUGIN:PlayerThink(player)
  if !player:Alive() and player:is_ragdolled() then
    hook.run('PlayerDeathThink', player)
  end
end
