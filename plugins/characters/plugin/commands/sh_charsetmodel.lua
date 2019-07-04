local COMMAND = Command.new('charsetmodel')
COMMAND.name = 'CharSetModel'
COMMAND.description = 'command.char_set_model.description'
COMMAND.syntax = 'command.char_set_model.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'perm.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setmodel' }

function COMMAND:on_run(player, targets, model)
  local target = targets[1]

  Flux.Player:broadcast('char_set_model.message', { get_player_name(player), target:name(), model })

  Characters.set_model(target, model)
end

COMMAND:register()
