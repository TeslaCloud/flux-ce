COMMAND.name = 'Unfreeze'
COMMAND.description = 'command.unfreeze.description'
COMMAND.syntax = 'command.unfreeze.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'unfreeze', 'plyunfreeze' }

function COMMAND:on_run(player, targets)
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
