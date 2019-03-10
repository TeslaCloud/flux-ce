cable.receive('fl_client_included_schema', function(player)
  hook.run('ClientIncludedSchema', player)
end)

cable.receive('fl_undo_soft', function(player)
  Flux.Undo:do_player(player)
end)

cable.receive('fl_player_created', function(player)
  player:send_config()
  player:sync_nv()
  hook.run('PlayerInitialized', player)
end)

cable.receive('fl_player_set_lang', function(player, lang)
  player:set_nv('language', lang)
end)
