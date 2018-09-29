netstream.Hook('ClientIncludedSchema', function(player)
  hook.run('ClientIncludedSchema', player)
  hook.run('PlayerInitialized', player)
end)

netstream.Hook('soft_undo', function(player)
  fl.undo:do_player(player)
end)

netstream.Hook('player_created', function(player)
  player:send_config()
  player:sync_nv()
end)

netstream.Hook('player_set_lang', function(player, lang)
  player:set_nv('language', lang)
end)
