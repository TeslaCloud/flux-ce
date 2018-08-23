local COMMAND = Command.new("charsetmodel")
COMMAND.name = "CharSetModel"
COMMAND.description = "#CharSetModel_Description"
COMMAND.syntax = "#CharSetModel_Syntax"
COMMAND.category = "character_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.Aliases = {"setmodel"}

function COMMAND:OnRun(player, targets, model)
  local target = targets[1]

  fl.player:NotifyAll(L("CharSetName_Message", (IsValid(player) and player:Name()) or "Console", target:Name(), model))

  character.SetModel(target, target:GetCharacter(), model)
end

COMMAND:register()
