--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("charsetmodel")
COMMAND.Name = "CharSetModel"
COMMAND.Description = "#CharSetModel_Description"
COMMAND.Syntax = "#CharSetModel_Syntax"
COMMAND.Category = "character_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"setmodel"}

function COMMAND:OnRun(player, targets, model)
	local target = targets[1]

	fl.player:NotifyAll(L("CharSetName_Message", (IsValid(player) and player:Name()) or "Console", target:Name(), model))

	character.SetModel(target, target:GetCharacter(), model)
end

COMMAND:Register()