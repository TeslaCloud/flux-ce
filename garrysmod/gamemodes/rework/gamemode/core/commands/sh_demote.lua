--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("demote")
COMMAND.name = "Demote"
COMMAND.description = "#DemoteCMD_Description"
COMMAND.syntax = "#DemoteCMD_Syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = {"plydemote"}

function COMMAND:OnRun(player, target)
	rw.player:NotifyAll(L("DemoteCMD_Message", (IsValid(player) and player:Name()) or "Console"), target:Name(), target:GetUserGroup())

	rw.player:SetUserGroup(target, "user")
end

COMMAND:Register()