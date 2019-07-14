COMMAND.name = 'CharSetDesc'
COMMAND.description = 'command.charsetdesc.description'
COMMAND.syntax = 'command.charsetdesc.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setdesc', 'setdescription', 'physdesc' }

function COMMAND:on_run(player, targets, ...)
  local new_desc = table.concat({ ... }, ' ')
  local target = targets[1]

  Characters.set_desc(target, new_desc)
  target:notify('notification.desc_changed', { desc = new_desc })

  self:notify_staff('command.charsetdesc.message', {
    player = get_player_name(player),
    target = util.player_list_to_string({ target }),
    desc = new_desc
  })
end
