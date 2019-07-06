COMMAND.name = 'CharSetName'
COMMAND.description = 'command.charsetname.description'
COMMAND.syntax = 'command.charsetname.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setname' }

function COMMAND:on_run(player, targets, ...)
  local new_name = table.concat({ ... }, ' ')
  local target = targets[1]

  self:notify_staff('command.charsetname.message', {
    player = get_player_name(player),
    target = util.player_list_to_string({ target }),
    name = new_name
  })

  Characters.set_name(target, new_name)
  target:notify('notification.name_changed', { name = new_name })
end
