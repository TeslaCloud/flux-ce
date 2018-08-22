netstream.Hook("ClientIncludedSchema", function(player)
  hook.Run("ClientIncludedSchema", player)
  hook.Run("PlayerInitialized", player)
end)

netstream.Hook("SoftUndo", function(player)
  fl.undo:DoPlayer(player)
end)

netstream.Hook("LocalPlayerCreated", function(player)
  netstream.Start(player, "SharedTables", fl.shared)

  player:SendConfig()
  player:SyncNetVars()
end)

netstream.Hook("Flux::Player::Language", function(player, lang)
  player:SetNetVar("language", lang)
end)
