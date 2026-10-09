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
  if !isstring(lang) or lang == '' or #lang > 16 then return end

  local old_lang = Flux.Lang:get_player_lang(actor)

  if old_lang == lang then return end

  actor:set_nv('language', lang)

  --- Called on the server when the client of a player has reported a new language: the one
  -- the player picked with `Flux.Lang:set_language`, or else the language of their game.
  -- Runs after `Flux.Lang:get_player_lang` has started to return the new language. Not
  -- called for the first report of a player whose language is English, which is what the
  -- server assumes until then.
  -- @param actor [Player The player whose language has changed]
  -- @param new_lang [String New language code]
  -- @param old_lang [String Previous language code]
  hook.Run('PlayerLanguageChanged', actor, lang, old_lang)
end)
