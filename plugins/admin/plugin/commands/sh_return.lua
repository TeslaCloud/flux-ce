--- The Return command teleports the targeted players back to where they were before they were
-- last teleported.

CMD.name = 'Return'
CMD.description = 'command.return.description'
CMD.syntax = 'command.return.syntax'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.arg_types = { 'player' }
CMD.immunity = true
CMD.aliases = { 'return', 'back' }

--- Teleports the targeted players back to where they were before their last teleport and
-- notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to return]
function CMD:on_run(actor, targets)
  for _, client in ipairs(targets) do
    if IsValid(client) and client.prev_pos then
      client:notify('notification.return')
      client:teleport(client.prev_pos)
      client.prev_pos = nil
    end
  end

  self:notify_staff('command.return.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
