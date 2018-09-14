local COMMAND = Command.new("changelevel")
COMMAND.name = "Changelevel"
COMMAND.description = "Changes the level to specified map."
COMMAND.syntax = "<string Map> [number Delay]"
COMMAND.category = "server_management"
COMMAND.arguments = 1
COMMAND.aliases = {"map"}

function COMMAND:on_run(player, map, delay)
  map = tostring(map) or "gm_construct"
  delay = tonumber(delay) or 10

  fl.player:broadcast("map_change_message", { get_player_name(player), map, delay })

  timer.Simple(delay, function()
    RunConsoleCommand("changelevel", map)
  end)
end

COMMAND:register()
