COMMAND.name = 'Freeze'
COMMAND.description = 'command.freeze.description'
COMMAND.syntax = 'command.freeze.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'freeze', 'plyfreeze' }

function COMMAND:on_run(player, targets)
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
