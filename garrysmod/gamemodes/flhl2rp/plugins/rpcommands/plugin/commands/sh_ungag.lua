--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("ungag")
COMMAND.name = "Ungag"
COMMAND.description = "Unmute player's OOC chats."
COMMAND.syntax = "<name>"
COMMAND.category = "administration"
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = {"unmuteooc", "oocunmute", "plyungag"}

function COMMAND:OnRun(player, targets)
	for k, v in ipairs(targets) do
		v:SetPlayerData("muteOOC", nil)
	end

	fl.player:NotifyAll(L("OOCUnmuteMessage", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets)))
end

COMMAND:Register()