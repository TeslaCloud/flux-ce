--- The Changelevel command changes the map to the given one, optionally after a delay in
-- seconds: `/changelevel <map> [delay]`. The map has to be named exactly, and the names of
-- the maps are suggested while it is typed. It refuses a map the server does not have, and
-- runs the `PreMapChange` hook before the change, as the Restart command does. The map
-- change saves everything through the gamemode's `ShutDown` handler.

CMD.name = 'Changelevel'
CMD.description = 'command.changelevel.description'
CMD.syntax = 'command.changelevel.syntax'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.arg_types = { 'map', 'number' }
CMD.alias = 'map'

--- Changes the map after an optional delay and notifies staff. The map has to be named
-- exactly as its file is, without the .bsp extension, in any case; the caller is told if the
-- server has no such map.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param map_name [String map name without the .bsp extension]
-- @param delay=0 [String delay in seconds]
function CMD:on_run(actor, map_name, delay)
  local map = game.find_map(tostring(map_name))

  delay = tonumber(delay)

  if !delay or delay != delay or delay < 0 or delay == math.huge then
    delay = 0
  end

  if !map then
    Flux.Player:notify(actor, 'error.map_not_valid', { map = tostring(map_name) })

    return
  end

  self:notify_staff('command.changelevel.message', {
    player = get_player_name(actor),
    map = map,
    delay = delay
  })

  timer.Simple(delay, function()
    --- Called on the server right before the Changelevel or the Restart command changes the
    -- map. The map change that follows saves everything through the gamemode's `ShutDown`
    -- handler.
    -- @param map [String name of the map that is about to be loaded]
    hook.Run('PreMapChange', map)

    RunConsoleCommand('changelevel', map)
  end)
end
