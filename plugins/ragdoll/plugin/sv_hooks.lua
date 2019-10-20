function PLUGIN:PlayerDeath(player)
  local delay = math.max(Config.get('corpse_remove_delay'), Config.get('respawn_delay'))

  local settings = {}
  settings.delay = delay

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
