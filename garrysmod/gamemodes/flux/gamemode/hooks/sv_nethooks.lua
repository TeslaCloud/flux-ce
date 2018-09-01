netstream.Hook("ClientIncludedSchema", function(player)
  hook.run("ClientIncludedSchema", player)
  hook.run("PlayerInitialized", player)
end)

netstream.Hook("soft_undo", function(player)
  fl.undo:DoPlayer(player)
end)

netstream.Hook("player_created", function(player)
  netstream.Heavy(player, "SharedTables", fl.shared)

  player:SendConfig()
  player:SyncNetVars()
end)

netstream.Hook("player_set_lang", function(player, lang)
  player:set_nv("language", lang)
end)
