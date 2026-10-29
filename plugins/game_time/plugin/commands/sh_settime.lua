--- The SetTime command sets the game clock to a date, a time of day or both, written as
-- 'YYYY-MM-DD HH:MM'. A date alone keeps the time of day and a time alone keeps the date.

CMD.name = 'SetTime'
CMD.description = 'command.settime.description'
CMD.syntax = 'command.settime.syntax'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.arg_types = { 'text' }
CMD.aliases = { 'setdate', 'setgametime' }

--- Sets the game clock to the date and time given in the argument and notifies staff. The
-- caller is told when the argument is not a date or a time, or when the clock cannot be
-- set because it follows the real time of the server.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param text [String the date, the time of day or both, as they were typed; a pair of
--   double quotes around all of it is left out]
function CMD:on_run(actor, text)
  local timestamp = GameTime:parse(text:match('^"([^"]*)"$') or text)

  if !timestamp then
    Flux.Player:notify(actor, 'error.game_time.invalid_format')

    return
  end

  local success, error_phrase = GameTime:set(timestamp)

  if !success then
    Flux.Player:notify(actor, error_phrase)

    return
  end

  self:notify_staff('command.settime.message', {
    player = get_player_name(actor),
    time = GameTime:to_string(timestamp)
  })
end
