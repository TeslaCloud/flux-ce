cable.receive('fl_hook_run_cl', function(hook_name, ...)
  hook.run(hook_name, ...)
end)

cable.receive('fl_player_initial_spawn', function(ply_index)
  hook.run('PlayerInitialSpawn', Entity(ply_index))
end)

cable.receive('fl_player_disconnected', function(ply_index)
  hook.run('PlayerDisconnected', Entity(ply_index))
end)

cable.receive('fl_player_model_changed', function(ply_index, new_model, old_model)
  util.wait_for_ent(ply_index, function(player)
    hook.run('PlayerModelChanged', player, new_model, old_model)
  end)
end)

cable.receive('fl_notification', function(message, arguments)
  if istable(arguments) then
    for k, v in pairs(arguments) do
      if isstring(v) then
        arguments[k] = t(v)
      end
    end
  end

  message = t(message, arguments)

  fl.notification:add(message, 8, Color(175, 175, 235))

  chat.AddText(Color(255, 255, 255), message)
end)

cable.receive('fl_player_take_damage', function()
  fl.client.last_damage = CurTime()
end)
