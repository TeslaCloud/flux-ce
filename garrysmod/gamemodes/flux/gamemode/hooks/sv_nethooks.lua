cable.receive('ClientIncludedSchema', function(player)
  hook.run('ClientIncludedSchema', player)
end)

cable.receive('soft_undo', function(player)
  fl.undo:do_player(player)
end)

cable.receive('player_created', function(player)
  player:send_config()
  player:sync_nv()
  hook.run('PlayerInitialized', player)
end)

cable.receive('player_set_lang', function(player, lang)
  player:set_nv('language', lang)
end)
