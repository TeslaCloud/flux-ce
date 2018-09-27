netstream.Hook('Hook_RunCL', function(hook_name, ...)
  hook.run(hook_name, ...)
end)

netstream.Hook('PlayerInitialSpawn', function(ply_index)
  hook.run('PlayerInitialSpawn', Entity(ply_index))
end)

netstream.Hook('PlayerDisconnected', function(ply_index)
  hook.run('PlayerDisconnected', Entity(ply_index))
end)

netstream.Hook('PlayerModelChanged', function(ply_index, new_model, old_model)
  util.wait_for_ent(ply_index, function(player)
    hook.run('PlayerModelChanged', player, new_model, old_model)
  end)
end)

netstream.Hook('fl_notification', function(message, arguments)
  message = t(message, arguments)

  fl.notification:Add(message, 8, Color(175, 175, 235))

  chat.AddText(Color(255, 255, 255), message)
end)

netstream.Hook('PlayerTakeDamage', function()
  fl.client.last_damage = CurTime()
end)
