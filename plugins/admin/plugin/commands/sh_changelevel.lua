COMMAND.name = 'Changelevel'
COMMAND.description = 'command.changelevel.description'
COMMAND.syntax = 'command.changelevel.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.arguments = 1
COMMAND.alias = 'map'

function COMMAND:on_run(player, map, delay)
  map = tostring(map) or 'gm_construct'
  delay = tonumber(delay) or 0

  self:notify_staff('command.changelevel.message', {
    player = get_player_name(player),
    map = map,
    delay = delay
  })

  timer.simple(delay, function()
    RunConsoleCommand('changelevel', map)
  end)
end
