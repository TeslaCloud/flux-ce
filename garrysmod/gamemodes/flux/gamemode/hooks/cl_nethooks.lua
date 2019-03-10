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

cable.receive('fl_notification', function(message, arguments, color)
  if istable(arguments) then
    for k, v in pairs(arguments) do
      if isstring(v) then
        arguments[k] = t(v)
      end
    end
  end

  color = color and Color(color.r, color.g, color.b) or color_white
  message = t(message, arguments)

  Flux.Notification:add(message, 8, color:darken(50))

  chat.AddText(color, message)
end)

cable.receive('fl_player_take_damage', function()
  Flux.client.last_damage = CurTime()
end)
