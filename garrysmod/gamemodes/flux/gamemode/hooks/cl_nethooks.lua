cable.receive('Hook_RunCL', function(hook_name, ...)
  hook.run(hook_name, ...)
end)

cable.receive('PlayerInitialSpawn', function(ply_index)
  hook.run('PlayerInitialSpawn', Entity(ply_index))
end)

cable.receive('PlayerDisconnected', function(ply_index)
  hook.run('PlayerDisconnected', Entity(ply_index))
end)

cable.receive('PlayerModelChanged', function(ply_index, new_model, old_model)
  util.wait_for_ent(ply_index, function(player)
    hook.run('PlayerModelChanged', player, new_model, old_model)
  end)
end)

cable.receive('fl_notification', function(message, arguments)
  message = t(message, arguments)

  fl.notification:add(message, 8, Color(175, 175, 235))

  chat.AddText(Color(255, 255, 255), message)
end)

cable.receive('PlayerTakeDamage', function()
  fl.client.last_damage = CurTime()
end)
