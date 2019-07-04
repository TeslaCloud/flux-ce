local COMMAND = Command.new('changelevel')
COMMAND.name = 'Changelevel'
COMMAND.description = 'command.changelevel.description'
COMMAND.syntax = 'command.changelevel.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'perm.categories.server_management'
COMMAND.arguments = 1
COMMAND.aliases = { 'map' }

function COMMAND:on_run(player, map, delay)
  map = tostring(map) or 'gm_construct'
  delay = tonumber(delay) or 10

  Flux.Player:broadcast('command.changelevel.message', { get_player_name(player), map, delay })

  timer.Simple(delay, function()
    RunConsoleCommand('changelevel', map)
  end)
end

COMMAND:register()
