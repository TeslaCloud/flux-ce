--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("freezebots")
COMMAND.name = "FreezeBots"
COMMAND.description = "Freezes all of the bots."
COMMAND.category = "server_management"
COMMAND.aliases = {"botfreeze", "freezebot", "bot_freeze", "bot_zombie"}

function COMMAND:OnRun(player)
	rw.player:NotifyAll(L("FreezeBotsMessage", (IsValid(player) and player:Name()) or "Console"))

	RunConsoleCommand("bot_zombie", 1)
end

COMMAND:Register()

local COMMAND = Command("unfreezebots")
COMMAND.name = "UnfreezeBots"
COMMAND.description = "Unfreezes all of the bots."
COMMAND.category = "server_management"
COMMAND.aliases = {"botunfreeze", "unfreezebot", "bot_unfreeze", "bot_unzombie"}

function COMMAND:OnRun(player)
	rw.player:NotifyAll(L("UnfreezeBotsMessage", (IsValid(player) and player:Name()) or "Console"))

	RunConsoleCommand("bot_zombie", 0)
end

COMMAND:Register()

local COMMAND = Command("addbots")
COMMAND.name = "AddBots"
COMMAND.description = "Adds specified amount of bots to the server."
COMMAND.syntax = "[number Bots]"
COMMAND.category = "server_management"
COMMAND.arguments = 0
COMMAND.aliases = {"bot", "bots"}

function COMMAND:OnRun(player, numBots)
	numBots = math.Clamp((tonumber(numBots) or 1), 1, 128)

	rw.player:NotifyAll(L("AddBotsMessage", (IsValid(player) and player:Name()) or "Console", numBots))

	timer.Create("ADD_BOTS", 0.2, numBots, function()
		RunConsoleCommand("bot")
	end)
end

COMMAND:Register()

local COMMAND = Command("kickbots")
COMMAND.name = "KickBots"
COMMAND.description = "Kicks all bots."
COMMAND.category = "server_management"
COMMAND.aliases = {"botkick", "kickbot", "bot_kick"}

function COMMAND:OnRun(player)
	rw.player:NotifyAll(L("KickBotsMessage", (IsValid(player) and player:Name()) or "Console"))

	for k, v in ipairs(_player.GetAll()) do
		if (v:IsBot()) then
			v:Kick("Kicking bots")
		end
	end
end

COMMAND:Register()