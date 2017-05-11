--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("setgroup")
COMMAND.name = "SetGroup"
COMMAND.description = "#SetGroupCMD_Description"
COMMAND.syntax = "#SetGroupCMD_Syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = {"plysetgroup", "setusergroup", "plysetusergroup"}

function COMMAND:OnRun(player, targets, userGroup)
	if (fl.admin:GroupExists(userGroup)) then
		for k, v in ipairs(targets) do
			v:SetUserGroup(userGroup)
		end

		fl.player:NotifyAll(L("SetGroupCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), userGroup))
	else
		fl.player:Notify(player, L("Err_GroupNotValid", userGroup))
	end
end

COMMAND:Register()