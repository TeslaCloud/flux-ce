--- The SetTime command sets the game clock to a date, a time of day or both, written as
-- 'YYYY-MM-DD HH:MM'. A date alone keeps the time of day and a time alone keeps the date.
-- Allowed for moderators by default.

CMD.name = 'SetTime'
CMD.description = 'command.settime.description'
CMD.syntax = 'command.settime.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.aliases = { 'setdate', 'setgametime' }

--- Sets the game clock to the date and time given in the arguments and notifies staff. The
-- caller is told when the arguments are not a date or a time, or when the clock cannot be
-- set because it follows the real time of the server.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param ... [Vararg the date, the time of day or both, as the pieces the command line was
--   split into]
function CMD:on_run(actor, ...)
  local timestamp = GameTime:parse(table.concat({ ... }, ' '))

  if !timestamp then
    Flux.Player:notify(actor, 'error.gametime.invalid_format')

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
