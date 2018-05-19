--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local COMMAND = Command("changelevel")
COMMAND.Name = "Changelevel"
COMMAND.Description = "Changes the level to specified map."
COMMAND.Syntax = "<string Map> [number Delay]"
COMMAND.Category = "server_management"
COMMAND.Arguments = 1
COMMAND.Aliases = {"map"}

function COMMAND:OnRun(player, map, delay)
  map = tostring(map) or "gm_construct"
  delay = tonumber(delay) or 10

  fl.player:NotifyAll(L("MapChangeMessage", (IsValid(player) and player:Name()) or "Console", map, delay))

  timer.Simple(delay, function()
    RunConsoleCommand("changelevel", map)
  end)
end

COMMAND:Register()
