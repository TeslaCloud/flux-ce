--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("charsetname")
COMMAND.Name = "CharSetName"
COMMAND.Description = "#CharSetName_Description"
COMMAND.Syntax = "#CharSetName_Syntax"
COMMAND.Category = "character_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"setname"}

function COMMAND:OnRun(player, targets, newName)
	local target = targets[1]

	fl.player:NotifyAll(L("CharSetName_Message", (IsValid(player) and player:Name()) or "Console", target:Name(), newName))

	character.SetName(target, target:GetCharacter(), newName)
end

COMMAND:Register()
