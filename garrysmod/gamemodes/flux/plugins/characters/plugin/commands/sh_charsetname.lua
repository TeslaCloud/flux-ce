local COMMAND = Command("charsetname")
COMMAND.name = "CharSetName"
COMMAND.description = "#CharSetName_Description"
COMMAND.Syntax = "#CharSetName_Syntax"
COMMAND.category = "character_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"setname"}

function COMMAND:OnRun(player, targets, newName)
  local target = targets[1]

  fl.player:NotifyAll(L("CharSetName_Message", (IsValid(player) and player:name()) or "Console", target:name(), newName))

  character.SetName(target, target:GetCharacter(), newName)
end

COMMAND:register()
