Cable.receive('fl_hook_run_cl', function(hook_name, ...)
  hook.run(hook_name, ...)
end)

Cable.receive('fl_player_initial_spawn', function(ply_index)
  hook.run('PlayerInitialSpawn', Entity(ply_index))
end)

Cable.receive('fl_player_disconnected', function(ply_index)
  hook.run('PlayerDisconnected', Entity(ply_index))
end)

Cable.receive('fl_player_model_changed', function(ply_index, new_model, old_model)
  util.wait_for_ent(ply_index, function(player)
    hook.run('PlayerModelChanged', player, new_model, old_model)
  end)
end)

Cable.receive('fl_notification', function(message, arguments, color)
  if IsValid(PLAYER) and PLAYER:has_initialized() then
    PLAYER:notify(message, arguments, color)
  end
end)

Cable.receive('fl_player_take_damage', function()
  PLAYER.last_damage = CurTime()
end)

Cable.receive('fl_player_interact', function(target)
  local interaction_menu = DermaMenu()

  hook.run('CreatePlayerInteractions', interaction_menu, target)

  if interaction_menu:ChildCount() > 0 then
    interaction_menu:Open()
    interaction_menu:Center()
  else
    interaction_menu:safe_remove()
  end
end)

Cable.receive('fl_entity_interact', function(entity)
  local interaction_menu = DermaMenu()

  hook.run('CreateEntityInteractions', interaction_menu, entity)

  if interaction_menu:ChildCount() > 0 then
    interaction_menu:Open()
    interaction_menu:Center()
  else
    interaction_menu:safe_remove()
  end
end)
