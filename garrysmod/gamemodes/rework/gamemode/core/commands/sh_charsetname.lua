--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local COMMAND = Command("charsetname")
COMMAND.name = "CharSetName"
COMMAND.description = "#CharSetName_Description"
COMMAND.syntax = "#CharSetName_Syntax"
COMMAND.category = "character_management"
COMMAND.arguments = 2
COMMAND.playerArg = 1
COMMAND.aliases = {"setname"}

function COMMAND:OnRun(player, target, newName)
	rw.player:NotifyAll(L("CharSetName_Message", (IsValid(player) and player:Name()) or "Console", target:Name(), newName))

	character.SetName(target, target:GetCharacter(), newName)
end

COMMAND:Register()