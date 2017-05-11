--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("unwhitelist")

COMMAND.name = "UnWhitelist"
COMMAND.description = "#TakeWhitelistCMD_Description"
COMMAND.syntax = "#TakeWhitelistCMD_Syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.playerArg = 1
COMMAND.aliases = {"takewhitelist", "plytakewhitelist", "plyunwhitelist"}

function COMMAND:OnRun(player, targets, name, bStrict)
	local whitelist = faction.Find(name, bStrict)

	if (whitelist) then
		for k, v in ipairs(targets) do
			if (v:HasWhitelist(whitelist.uniqueID)) then
				v:TakeWhitelist(whitelist.uniqueID)
			elseif (#targets == 1) then
				fl.player:Notify(player, L("Err_TargetNotWhitelisted", v:Name(), whitelist.PrintName))

				return
			end
		end

		fl.player:NotifyAll(L("TakeWhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), whitelist.PrintName))
	else
		fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
	end
end

COMMAND:Register()