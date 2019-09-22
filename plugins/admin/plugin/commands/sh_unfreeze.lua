CMD.name = 'Unfreeze'
CMD.description = 'command.unfreeze.description'
CMD.syntax = 'command.unfreeze.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'unfreeze', 'plyunfreeze' }

function CMD:on_run(player, targets)
  for k, v in ipairs(targets) do
    v:Freeze(false)
    v:notify('notification.unfreeze', {
      player = player
    })
  end

  self:notify_staff('command.unfreeze.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
