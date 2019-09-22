CMD.name = 'Changelevel'
CMD.description = 'command.changelevel.description'
CMD.syntax = 'command.changelevel.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.alias = 'map'

function CMD:on_run(player, map, delay)
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
