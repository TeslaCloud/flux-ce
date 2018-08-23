local COMMAND = Command("freezebots")
COMMAND.name = "FreezeBots"
COMMAND.description = "Freezes all of the bots."
COMMAND.category = "server_management"
COMMAND.Aliases = {"botfreeze", "freezebot", "bot_freeze", "bot_zombie"}

function COMMAND:OnRun(player)
  fl.player:NotifyAll(L("FreezeBotsMessage", (IsValid(player) and player:name()) or "Console"))

  RunConsoleCommand("bot_zombie", 1)
end

COMMAND:register()

local COMMAND = Command("unfreezebots")
COMMAND.name = "UnfreezeBots"
COMMAND.description = "Unfreezes all of the bots."
COMMAND.category = "server_management"
COMMAND.Aliases = {"botunfreeze", "unfreezebot", "bot_unfreeze", "bot_unzombie"}

function COMMAND:OnRun(player)
  fl.player:NotifyAll(L("UnfreezeBotsMessage", (IsValid(player) and player:name()) or "Console"))

  RunConsoleCommand("bot_zombie", 0)
end

COMMAND:register()

local COMMAND = Command("addbots")
COMMAND.name = "AddBots"
COMMAND.description = "Adds specified amount of bots to the server."
COMMAND.Syntax = "[number Bots]"
COMMAND.category = "server_management"
COMMAND.Arguments = 0
COMMAND.Aliases = {"bot", "bots"}

function COMMAND:OnRun(player, numBots)
  numBots = math.Clamp((tonumber(numBots) or 1), 1, 128)

  fl.player:NotifyAll(L("AddBotsMessage", (IsValid(player) and player:name()) or "Console", numBots))

  timer.Create("ADD_BOTS", 0.2, numBots, function()
    RunConsoleCommand("bot")
  end)
end

COMMAND:register()

local COMMAND = Command("kickbots")
COMMAND.name = "KickBots"
COMMAND.description = "Kicks all bots."
COMMAND.category = "server_management"
COMMAND.Aliases = {"botkick", "kickbot", "bot_kick"}

function COMMAND:OnRun(player)
  fl.player:NotifyAll(L("KickBotsMessage", (IsValid(player) and player:name()) or "Console"))

  for k, v in ipairs(_player.GetAll()) do
    if (v:IsBot()) then
      v:Kick("Kicking bots")
    end
  end
end

COMMAND:register()
