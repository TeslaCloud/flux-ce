local COMMAND = Command.new("charsetname")
COMMAND.name = "CharSetName"
COMMAND.description = "#CharSetName_Description"
COMMAND.syntax = "#CharSetName_Syntax"
COMMAND.category = "character_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.Aliases = {"setname"}

function COMMAND:OnRun(player, targets, newName)
  local target = targets[1]

  fl.player:NotifyAll(L("CharSetName_Message", (IsValid(player) and player:Name()) or "Console", target:Name(), newName))

  character.set_name(target, target:GetCharacter(), newName)
end

COMMAND:register()
