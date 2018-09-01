local COMMAND = Command.new("charsetname")
COMMAND.name = "CharSetName"
COMMAND.description = t"char_set_name.description"
COMMAND.syntax = t"char_set_name.syntax"
COMMAND.category = "character_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = {"setname"}

function COMMAND:on_run(player, targets, newName)
  local target = targets[1]

  fl.player:broadcast(L("CharSetName_Message", (IsValid(player) and player:Name()) or "Console", target:Name(), newName))

  character.set_name(target, target:GetCharacter(), newName)
end

COMMAND:register()
