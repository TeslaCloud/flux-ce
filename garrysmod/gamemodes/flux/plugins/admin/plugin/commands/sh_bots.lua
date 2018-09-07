local COMMAND = Command.new("freezebots")
COMMAND.name = "FreezeBots"
COMMAND.description = "Freezes all of the bots."
COMMAND.category = "server_management"
COMMAND.aliases = {"botfreeze", "freezebot", "bot_freeze", "bot_zombie"}

function COMMAND:on_run(player)
  fl.player:broadcast(L("FreezeBotsMessage", (IsValid(player) and player:Name()) or "Console"))

  RunConsoleCommand("bot_zombie", 1)
end

COMMAND:register()

local COMMAND = Command.new("unfreezebots")
COMMAND.name = "UnfreezeBots"
COMMAND.description = "Unfreezes all of the bots."
COMMAND.category = "server_management"
COMMAND.aliases = {"botunfreeze", "unfreezebot", "bot_unfreeze", "bot_unzombie"}

function COMMAND:on_run(player)
  fl.player:broadcast(L("UnfreezeBotsMessage", (IsValid(player) and player:Name()) or "Console"))

  RunConsoleCommand("bot_zombie", 0)
end

COMMAND:register()

local COMMAND = Command.new("addbots")
COMMAND.name = "AddBots"
COMMAND.description = "Adds specified amount of bots to the server."
COMMAND.syntax = "[number Bots]"
COMMAND.category = "server_management"
COMMAND.arguments = 0
COMMAND.aliases = {"bot", "bots"}

function COMMAND:on_run(player, numBots)
  numBots = math.Clamp((tonumber(numBots) or 1), 1, 128)

  fl.player:broadcast(L("AddBotsMessage", (IsValid(player) and player:Name()) or "Console", numBots))

  timer.Create("ADD_BOTS", 0.2, numBots, function()
    RunConsoleCommand("bot")
  end)
end

COMMAND:register()

local COMMAND = Command.new("kickbots")
COMMAND.name = "KickBots"
COMMAND.description = "Kicks all bots."
COMMAND.category = "server_management"
COMMAND.aliases = {"botkick", "kickbot", "bot_kick"}

function COMMAND:on_run(player)
  fl.player:broadcast(L("KickBotsMessage", (IsValid(player) and player:Name()) or "Console"))

  for k, v in ipairs(_player.GetAll()) do
    if v:IsBot() then
      v:Kick("Kicking bots")
    end
  end
end

COMMAND:register()
