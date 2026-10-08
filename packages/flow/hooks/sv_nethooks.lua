--- Server-side receivers of the gamemode's network messages: the client's reports that it
-- has included the schema and created its local player (which run `ClientIncludedSchema`
-- and `PlayerInitialized`), soft undo requests and the client's language.

Cable.receive('fl_client_included_schema', function(actor)
  --- Called on the server when the client of a player reports that it has included the
  -- schema files. `FluxClientSchemaLoaded` is its client-side counterpart.
  -- @param actor [Player The player whose client has loaded the schema]
  hook.Run('ClientIncludedSchema', actor)
end)

Cable.receive('fl_undo_soft', function(actor)
  Flux.Undo:do_player(actor)
end)

Cable.receive('fl_player_created', function(actor)
  actor:send_config()
  actor:sync_nv()
  --- Called on the server when the client of a player has finished loading and reports
  -- that its local player exists, right after the config and the networked variables
  -- have been sent to it. The gamemode's handler marks the player as initialized (see
  -- `Player:has_initialized`) and, a quarter of a second later, runs the hook on the
  -- player's own client, where it is called without arguments. Not called for bots,
  -- which are marked as initialized as soon as they join.
  -- @param actor [Player The player who has finished loading; nil on the client]
  hook.Run('PlayerInitialized', actor)
end)

Cable.receive('fl_player_set_lang', function(actor, lang)
  actor:set_nv('language', lang)
end)
