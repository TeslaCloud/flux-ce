Cable.receive('fl_client_included_schema', function(actor)
  hook.run('ClientIncludedSchema', actor)
end)

Cable.receive('fl_undo_soft', function(actor)
  Flux.Undo:do_player(actor)
end)

Cable.receive('fl_player_created', function(actor)
  actor:send_config()
  actor:sync_nv()
  hook.run('PlayerInitialized', actor)
end)

Cable.receive('fl_player_set_lang', function(actor, lang)
  actor:set_nv('language', lang)
end)
