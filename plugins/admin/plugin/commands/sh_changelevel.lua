--- The Changelevel command changes the map to the given one, optionally after a delay in
-- seconds. It refuses a map the server does not have, and runs the `FLSaveData` and
-- `ServerRestart` hooks before the change, as the Restart command does. Allowed for
-- moderators by default.

CMD.name = 'Changelevel'
CMD.description = 'command.changelevel.description'
CMD.syntax = 'command.changelevel.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.alias = 'map'

--- Checks whether the server has a map with the given name. A name may only consist of
-- letters, digits, underscores, dashes and dots, since it ends up in a file path and in a
-- console command.
-- @param name [String map name without the .bsp extension]
-- @return [Boolean]
local function map_exists(name)
  return name:match('^[%w_%-%.]+$') != nil and file.Exists('maps/'..name..'.bsp', 'GAME')
end

--- Changes the map after an optional delay, saving data first, and notifies staff. The
-- caller is told if the server has no map with that name, as it was typed or in lowercase.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param map [String map name without the .bsp extension]
-- @param delay=0 [String delay in seconds]
function CMD:on_run(actor, map, delay)
  map = tostring(map)
  delay = tonumber(delay)

  if !delay or delay != delay or delay < 0 or delay == math.huge then
    delay = 0
  end

  if !map_exists(map) then
    if !map_exists(map:lower()) then
      Flux.Player:notify(actor, 'error.map_not_valid', { map = map })

      return
    end

    map = map:lower()
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
