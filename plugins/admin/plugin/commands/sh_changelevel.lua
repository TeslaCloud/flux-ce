CMD.name = 'Changelevel'
CMD.description = 'command.changelevel.description'
CMD.syntax = 'command.changelevel.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.alias = 'map'

--- Changes the map after an optional delay and notifies staff.
-- @param player [Player the caller, or an invalid entity when run from the server console]
-- @param map [String map name]
-- @param delay=0 [String delay in seconds]
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
