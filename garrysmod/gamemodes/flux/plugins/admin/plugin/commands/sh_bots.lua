--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]local COMMAND = Command("freezebots")
COMMAND.Name = "FreezeBots"
COMMAND.Description = "Freezes all of the bots."
COMMAND.Category = "server_management"
COMMAND.Aliases = {"botfreeze", "freezebot", "bot_freeze", "bot_zombie"}

function COMMAND:OnRun(player)
  fl.player:NotifyAll(L("FreezeBotsMessage", (IsValid(player) and player:Name()) or "Console"))

  RunConsoleCommand("bot_zombie", 1)
end

COMMAND:Register()

local COMMAND = Command("unfreezebots")
COMMAND.Name = "UnfreezeBots"
COMMAND.Description = "Unfreezes all of the bots."
COMMAND.Category = "server_management"
COMMAND.Aliases = {"botunfreeze", "unfreezebot", "bot_unfreeze", "bot_unzombie"}

function COMMAND:OnRun(player)
  fl.player:NotifyAll(L("UnfreezeBotsMessage", (IsValid(player) and player:Name()) or "Console"))

  RunConsoleCommand("bot_zombie", 0)
end

COMMAND:Register()

local COMMAND = Command("addbots")
COMMAND.Name = "AddBots"
COMMAND.Description = "Adds specified amount of bots to the server."
COMMAND.Syntax = "[number Bots]"
COMMAND.Category = "server_management"
COMMAND.Arguments = 0
COMMAND.Aliases = {"bot", "bots"}

function COMMAND:OnRun(player, numBots)
  numBots = math.Clamp((tonumber(numBots) or 1), 1, 128)

  fl.player:NotifyAll(L("AddBotsMessage", (IsValid(player) and player:Name()) or "Console", numBots))

  timer.Create("ADD_BOTS", 0.2, numBots, function()
    RunConsoleCommand("bot")
  end)
end

COMMAND:Register()

local COMMAND = Command("kickbots")
COMMAND.Name = "KickBots"
COMMAND.Description = "Kicks all bots."
COMMAND.Category = "server_management"
COMMAND.Aliases = {"botkick", "kickbot", "bot_kick"}

function COMMAND:OnRun(player)
  fl.player:NotifyAll(L("KickBotsMessage", (IsValid(player) and player:Name()) or "Console"))

  for k, v in ipairs(_player.GetAll()) do
    if (v:IsBot()) then
      v:Kick("Kicking bots")
    end
  end
end

COMMAND:Register()
