local COMMAND = Command.new("restart")
COMMAND.name = "Restart"
COMMAND.description = "Restarts the current map."
COMMAND.syntax = "[number Delay]"
COMMAND.category = "server_management"
COMMAND.arguments = 0
COMMAND.aliases = {"maprestart"}

function COMMAND:on_run(player, delay)
  delay = tonumber(delay) or 0

  fl.player:broadcast(L("MapRestartMessage", (IsValid(player) and player:Name()) or "Console", delay))

  timer.Simple(delay, function()
    hook.run("FLSaveData")

    RunConsoleCommand("changelevel", game.GetMap())
  end)
end

COMMAND:register()
