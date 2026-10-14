--- The `ungag` staff command: lifts the OOC mute of players.

CMD.name = 'Ungag'
CMD.description = 'command.ungag.description'
CMD.syntax = 'command.ungag.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'unmuteooc', 'oocunmute', 'plyungag' }

--- Lifts the OOC mute of the target players and notifies the staff.
-- @param actor [Player player running the command; not valid when run from the server console]
-- @param targets [List<Player> players to ungag]
function CMD:on_run(actor, targets)
  for k, v in ipairs(targets) do
    RPCommands:set_ooc_mute(v)
    v:notify('notification.unmuted')
  end

  self:notify_staff('command.ungag.message', {
    admin = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
