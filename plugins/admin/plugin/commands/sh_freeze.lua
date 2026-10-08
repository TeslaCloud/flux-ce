--- The Freeze command freezes the targeted players in place. Allowed for assistants by
-- default.

CMD.name = 'Freeze'
CMD.description = 'command.freeze.description'
CMD.syntax = 'command.freeze.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'freeze', 'plyfreeze' }

--- Freezes the targeted players in place and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to freeze]
function CMD:on_run(actor, targets)
  for k, v in ipairs(targets) do
    v:Freeze(true)
    v:notify('notification.freeze', {
      player = actor
    })
  end

  self:notify_staff('command.freeze.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
