--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("flstart")
COMMAND.name = "Restart"
COMMAND.description = "Restarts the current map."
COMMAND.syntax = "[number Delay]"
COMMAND.category = "server_management"
COMMAND.arguments = 0
COMMAND.aliases = {"maprestart"}

function COMMAND:OnRun(player, delay)
	delay = tonumber(delay) or 10

	fl.player:NotifyAll(L("MapRestartMessage", (IsValid(player) and player:Name()) or "Console", delay))

	timer.Simple(delay, function()
		RunConsoleCommand("changelevel", game.GetMap())
	end)
end

COMMAND:Register()