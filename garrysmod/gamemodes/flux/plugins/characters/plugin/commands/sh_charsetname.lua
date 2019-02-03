local COMMAND = Command.new('charsetname')
COMMAND.name = 'CharSetName'
COMMAND.description = t'char_set_name.description'
COMMAND.syntax = t'char_set_name.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setname' }

function COMMAND:on_run(player, targets, new_name)
  local target = targets[1]

  fl.player:broadcast('char_set_name.message', { get_player_name(player), target:name(), new_name })

  character.set_name(target, target:get_character(), new_name)
end

COMMAND:register()
