local COMMAND = Command.new('charsetname')
COMMAND.name = 'CharSetName'
COMMAND.description = 'command.char_set_name.description'
COMMAND.syntax = 'command.char_set_name.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setname' }

function COMMAND:on_run(player, targets, ...)
  local new_name = table.concat({ ... }, ' ')
  local target = targets[1]

  Flux.Player:broadcast('char_set_name.message', { get_player_name(player), target:name(), new_name })

  Characters.set_name(target, new_name)
end

COMMAND:register()
