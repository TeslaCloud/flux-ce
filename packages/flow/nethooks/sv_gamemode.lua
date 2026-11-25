--- Server-side receivers of the gamemode's network messages: the client's reports that it
-- has included the schema and created its local player (which run `PlayerSchemaLoaded`
-- and `PlayerInitialized`, once for each player) and the client's language, which is
-- applied at most once a second: a report that comes sooner is applied when the second
-- has passed, unless a later one replaces it.

local IsValid = IsValid
local CurTime = CurTime

Cable.receive('fl_client_included_schema', function(actor)
  if actor.fl_schema_loaded then return end

  actor.fl_schema_loaded = true

  --- Called on the server when the client of a player reports that it has included the
  -- schema files, once for each player. `ClientSchemaLoaded` is its client-side
  -- counterpart.
  -- @param actor [Player The player whose client has loaded the schema]
  hook.Run('PlayerSchemaLoaded', actor)
end)

Cable.receive('fl_player_created', function(actor)
  if actor:has_initialized() then return end

  actor:send_config()
  actor:sync_nv()
  Plugin.send_disabled(actor)
  actor:set_initialized(true)

  --- Called on the server when the client of a player has finished loading and reports
  -- that its local player exists, right after the config, the networked variables and
  -- the list of disabled plugins have been sent to it and the player has been marked as
  -- initialized (see `Player:has_initialized`). The gamemode's handler, a quarter of a
  -- second later, runs the hook on the player's own client, where it is called without
  -- arguments. Not called for bots, which are marked as initialized as soon as they join.
  -- @param actor [Player The player who has finished loading; nil on the client]
  hook.Run('PlayerInitialized', actor)
end)

--- Makes the language that the client of a player has reported last the language of the
-- player, if it differs from the one they have.
-- @param actor [Player]
local function apply_language(actor)
  local lang = actor.fl_reported_lang
  local old_lang = Flux.Lang:get_player_lang(actor)

  if old_lang == lang then return end

  actor.fl_next_lang = CurTime() + 1

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
end

Cable.receive('fl_player_set_lang', function(actor, lang)
  if !IsValid(actor) or !isstring(lang) or lang == '' or #lang > 16 then return end

  actor.fl_reported_lang = lang

  local wait = (actor.fl_next_lang or 0) - CurTime()

  if wait <= 0 then
    apply_language(actor)

    return
  end

  timer.Create('fl_player_lang_'..actor:EntIndex(), wait, 1, function()
    if IsValid(actor) then
      apply_language(actor)
    end
  end)
end)
