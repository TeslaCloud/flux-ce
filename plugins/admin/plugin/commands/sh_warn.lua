CMD.name = 'Warn'
CMD.description = 'command.warn.description'
CMD.syntax = 'command.warn.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'plywarn', 'warn' }

--- Sends a warning with the given reason to the targeted players and notifies staff. Without
-- a reason only the caller is notified.
-- @param player [Player the caller, or an invalid entity when run from the server console]
-- @param targets [Array<Player> players to warn]
-- @param ... [Vararg words of the warning reason]
function CMD:on_run(player, targets, ...)
  local reason = table.concat({ ... }, ' ')

  if !reason or reason == '' then
    player:notify('This is not a valid reason!')
  else
    self:notify_staff('command.warn.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      reason = reason
    })

    for k, v in ipairs(targets) do
      v:notify( "notification.warn", {
        reason = reason
      })
    end
  end
end
