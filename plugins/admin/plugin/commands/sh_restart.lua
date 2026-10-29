--- The Restart command reloads the current map, optionally after a delay in seconds. It runs the
-- `ServerRestart` hook first. The map change saves everything through the gamemode's
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
    --- Called on the server when the Restart command is about to reload the map. The
    -- gamemode's handler saves the data of every player.
    hook.Run('ServerRestart')

    RunConsoleCommand('changelevel', game.GetMap())
  end)
end
