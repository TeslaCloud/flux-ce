--- The Warn command sends the targeted players a warning with the given reason.

CMD.name = 'Warn'
CMD.description = 'command.warn.description'
CMD.syntax = 'command.warn.syntax'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.arg_types = { 'player', 'text' }
CMD.immunity = true
CMD.aliases = { 'plywarn', 'warn' }

--- Sends a warning with the given reason to the targeted players and notifies staff. Without
-- a reason only the caller is notified.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to warn]
-- @param reason=nil [String the warning reason, as it was typed]
function CMD:on_run(actor, targets, reason)
  if !reason or reason == '' then
    actor:notify('This is not a valid reason!')
  else
    self:notify_staff('command.warn.message', {
      player = get_player_name(actor),
      target = util.player_list_to_string(targets),
      reason = reason
    })

    for _, client in ipairs(targets) do
      client:notify('notification.warn', {
        reason = reason
      })
    end
  end
end
