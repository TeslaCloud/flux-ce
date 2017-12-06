--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("setfaction")

COMMAND.Name = "Setfaction"
COMMAND.Description = "Change player's faction."
COMMAND.Syntax = "<name> <faction> [data]"
COMMAND.Category = "player_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"plytransfer", "charsetfaction", "chartransfer"}

function COMMAND:OnRun(player, targets, name, bStrict)
	local factionTable = faction.Find(name, (bStrict and true) or false)

	if (factionTable) then
		for k, v in ipairs(targets) do
			v:SetFaction(factionTable.uniqueID)
		end

		fl.player:NotifyAll(L("SetfactionCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), factionTable.PrintName))
	else
		fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
	end
end

COMMAND:Register()