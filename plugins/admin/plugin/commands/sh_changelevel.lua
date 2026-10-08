--- The Changelevel command changes the map to the given one, optionally after a delay in
-- seconds. Allowed for moderators by default.

CMD.name = 'Changelevel'
CMD.description = 'command.changelevel.description'
CMD.syntax = 'command.changelevel.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.alias = 'map'

--- Changes the map after an optional delay and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param map [String map name]
-- @param delay=0 [String delay in seconds]
function CMD:on_run(actor, map, delay)
  map = tostring(map) or 'gm_construct'
  delay = tonumber(delay) or 0

  self:notify_staff('command.changelevel.message', {
    player = get_player_name(actor),
    map = map,
    delay = delay
  })

  timer.Simple(delay, function()
    RunConsoleCommand('changelevel', map)
  end)
end
