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

function COMMAND:OnRun(player, targets, name, bStrict)
	local whitelist = faction.Find(name, (bStrict and true) or false)

	if (whitelist) then
		for k, v in ipairs(targets) do
			v:GiveWhitelist(whitelist.uniqueID)
		end

		fl.player:NotifyAll(L("WhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), whitelist.PrintName))
	else
		fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
	end
end

COMMAND:Register()