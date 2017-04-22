--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("whitelist")

COMMAND.name = "Whitelist"
COMMAND.description = "#WhitelistCMD_Description"
COMMAND.syntax = "#WhitelistCMD_Syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.playerArg = 1
COMMAND.aliases = {"plywhitelist", "givewhitelist", "setwhitelisted"}

function COMMAND:OnRun(player, target, name, bStrict)
	local whitelist = faction.Find(name, (bStrict and true) or false)

	if (whitelist) then
		target:GiveWhitelist(whitelist.uniqueID)

		fl.player:NotifyAll(L("WhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", target:Name(), whitelist.PrintName))
	else
		fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
	end
end

COMMAND:Register()