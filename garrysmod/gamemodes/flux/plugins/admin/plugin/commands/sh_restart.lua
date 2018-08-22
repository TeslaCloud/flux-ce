local COMMAND = Command("restart")
COMMAND.Name = "Restart"
COMMAND.Description = "Restarts the current map."
COMMAND.Syntax = "[number Delay]"
COMMAND.Category = "server_management"
COMMAND.Arguments = 0
COMMAND.Aliases = {"maprestart"}

function COMMAND:OnRun(player, delay)
  delay = tonumber(delay) or 0

  fl.player:NotifyAll(L("MapRestartMessage", (IsValid(player) and player:Name()) or "Console", delay))

  timer.Simple(delay, function()
    hook.Run("FLSaveData")

    RunConsoleCommand("changelevel", game.GetMap())
  end)
end

COMMAND:Register()
