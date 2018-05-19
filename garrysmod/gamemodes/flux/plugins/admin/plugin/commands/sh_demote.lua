--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("demote")
COMMAND.Name = "Demote"
COMMAND.Description = "#DemoteCMD_Description"
COMMAND.Syntax = "#DemoteCMD_Syntax"
COMMAND.Category = "player_management"
COMMAND.Arguments = 1
COMMAND.Immunity = true
COMMAND.Aliases = {"plydemote"}

function COMMAND:OnRun(player, targets)
	for k, target in ipairs(targets) do
		target:SetUserGroup("user")

		fl.player:NotifyAll(L("DemoteCMD_Message", (IsValid(player) and player:Name()) or "Console"), target:Name(), target:GetUserGroup())
	end
end

COMMAND:Register()
