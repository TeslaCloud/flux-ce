--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local COMMAND = Command("addbots");
COMMAND.name = "AddBots";
COMMAND.description = "Adds specified amount of bots to the server.";
COMMAND.syntax = "[number Bots]";
COMMAND.category = "server_management";
COMMAND.arguments = 0;
COMMAND.aliases = {"bot", "bots"};

function COMMAND:OnRun(player, numBots)
	numBots = math.Clamp((tonumber(numBots) or 1), 1, 128);

	rw.player:NotifyAll(L("AddBotsMessage", (IsValid(player) and player:Name()) or "Console", numBots));
	
	timer.Create("ADD_BOTS", 0.2, numBots, function()
		RunConsoleCommand("bot");
	end);
end;

COMMAND:Register();

local COMMAND = Command("kickbots");
COMMAND.name = "KickBots";
COMMAND.description = "Kicks all bots.";
COMMAND.category = "server_management";
COMMAND.aliases = {"botkick", "kickbot", "bot_kick"};

function COMMAND:OnRun(player)
	rw.player:NotifyAll(L("KickBotsMessage", (IsValid(player) and player:Name()) or "Console"));
	
	for k, v in ipairs(_player.GetAll()) do
		if (v:IsBot()) then
			v:Kick("Kicking bots");
		end;
	end;
end;

COMMAND:Register();