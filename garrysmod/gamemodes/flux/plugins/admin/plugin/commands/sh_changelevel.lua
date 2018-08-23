local COMMAND = Command("changelevel")
COMMAND.name = "Changelevel"
COMMAND.description = "Changes the level to specified map."
COMMAND.syntax = "<string Map> [number Delay]"
COMMAND.category = "server_management"
COMMAND.arguments = 1
COMMAND.Aliases = {"map"}

function COMMAND:OnRun(player, map, delay)
  map = tostring(map) or "gm_construct"
  delay = tonumber(delay) or 10

  fl.player:NotifyAll(L("MapChangeMessage", (IsValid(player) and player:Name()) or "Console", map, delay))

  timer.Simple(delay, function()
    RunConsoleCommand("changelevel", map)
  end)
end

COMMAND:register()
