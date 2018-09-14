local COMMAND = Command.new("charsetmodel")
COMMAND.name = "CharSetModel"
COMMAND.description = t"char_set_model.description"
COMMAND.syntax = t"char_set_model.syntax"
COMMAND.category = "character_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = {"setmodel"}

function COMMAND:on_run(player, targets, model)
  local target = targets[1]

  fl.player:broadcast("char_set_model.message", { get_player_name(player), target:Name(), model })

  character.SetModel(target, target:GetCharacter(), model)
end

COMMAND:register()
