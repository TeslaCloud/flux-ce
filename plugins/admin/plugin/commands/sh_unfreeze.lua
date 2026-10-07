CMD.name = 'Unfreeze'
CMD.description = 'command.unfreeze.description'
CMD.syntax = 'command.unfreeze.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'unfreeze', 'plyunfreeze' }

--- Unfreezes the targeted players and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to unfreeze]
function CMD:on_run(actor, targets)
  for k, v in ipairs(targets) do
    v:Freeze(false)
    v:notify('notification.unfreeze', {
      player = actor
    })
  end

  self:notify_staff('command.unfreeze.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
