--- The Changelevel command changes the map to the given one, optionally after a delay in
-- seconds: `/changelevel <map> [delay]`. The map has to be named exactly, and the names of
-- the maps are suggested while it is typed. It refuses a map the server does not have, and
-- runs the `FLSaveData` and `ServerRestart` hooks before the change, as the Restart command
-- does.

CMD.name = 'Changelevel'
CMD.description = 'command.changelevel.description'
CMD.syntax = 'command.changelevel.syntax'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.arg_types = { 'map', 'text' }
CMD.alias = 'map'

--- Changes the map after an optional delay, saving data first, and notifies staff. The map
-- has to be named exactly as its file is, without the .bsp extension, in any case; the
-- caller is told if the server has no such map.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param map_name [String map name without the .bsp extension]
-- @param delay=0 [String delay in seconds]
function CMD:on_run(actor, map_name, delay)
  local map = Bolt:find_map(tostring(map_name))

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
    --- Run on the server by the Changelevel command right before the map changes, so that
    -- everything is saved first. This is the hook Flux also runs from its periodic save; the
    -- gamemode's handler saves the config and runs the `SaveData` hook.
    hook.Run('FLSaveData')
    --- Called on the server when the Changelevel command is about to change the map, after
    -- the `FLSaveData` hook has run, the same way the Restart command calls it. The
    -- gamemode's handler saves the data of every player.
    hook.Run('ServerRestart')

    RunConsoleCommand('changelevel', map)
  end)
end
