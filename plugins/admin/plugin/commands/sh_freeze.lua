CMD.name = 'Freeze'
CMD.description = 'command.freeze.description'
CMD.syntax = 'command.freeze.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'freeze', 'plyfreeze' }

function CMD:on_run(player, targets)
  for k, v in ipairs(targets) do
    v:Freeze(true)
    v:notify('notification.freeze', {
      player = player
    })
  end

  self:notify_staff('command.freeze.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
