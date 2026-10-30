--- The Restart command reloads the current map, optionally after a delay in seconds. It runs the
-- `PreChangeMap` hook first. The map change saves everything through the gamemode's
-- `ShutDown` handler.

CMD.name = 'Restart'
CMD.description = 'command.restart.description'
CMD.syntax = 'command.restart.syntax'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 0
CMD.arg_types = { 'number' }
CMD.alias = 'maprestart'

--- Restarts the current map after an optional delay and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param delay=0 [String delay in seconds]
function CMD:on_run(actor, delay)
  delay = tonumber(delay)

  if !delay or delay != delay or delay < 0 or delay == math.huge then
    delay = 0
  end

  self:notify_staff('command.restart.message', {
    player = get_player_name(actor),
    delay = delay
  })

  timer.Simple(delay, function()
    local map = game.GetMap()

    --- Called on the server right before the Restart or the Changelevel command changes the
    -- map; the Restart command changes it to the current one. The map change that follows
    -- saves everything through the gamemode's `ShutDown` handler.
    -- @param map [String name of the map that is about to be loaded]
    hook.Run('PreChangeMap', map)

    RunConsoleCommand('changelevel', map)
  end)
end
