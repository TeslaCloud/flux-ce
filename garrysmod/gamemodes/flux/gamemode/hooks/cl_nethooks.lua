netstream.Hook("SharedTables", function(tSharedTable)
  fl.shared = tSharedTable or {}
  fl.shared_received = true
end)

netstream.Hook("Hook_RunCL", function(hookName, ...)
  hook.run(hookName, ...)
end)

netstream.Hook("PlayerInitialSpawn", function(nPlyIndex)
  hook.run("PlayerInitialSpawn", Entity(nPlyIndex))
end)

netstream.Hook("PlayerDisconnected", function(nPlyIndex)
  hook.run("PlayerDisconnected", Entity(nPlyIndex))
end)

netstream.Hook("PlayerModelChanged", function(nPlyIndex, sNewModel, sOldModel)
  util.wait_for_ent(nPlyIndex, function(player)
    hook.run("PlayerModelChanged", player, sNewModel, sOldModel)
  end)
end)

netstream.Hook("flNotification", function(sMessage)
  sMessage = fl.lang:TranslateText(sMessage)

  fl.notification:Add(sMessage, 8, Color(175, 175, 235))

  chat.AddText(Color(255, 255, 255), sMessage)
end)

netstream.Hook("PlayerTakeDamage", function()
  fl.client.lastDamage = CurTime()
end)
