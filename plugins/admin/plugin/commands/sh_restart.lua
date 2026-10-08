--- The Restart command reloads the current map, optionally after a delay in seconds. It
-- runs the `FLSaveData` and `ServerRestart` hooks first. Allowed for moderators by default.

CMD.name = 'Restart'
CMD.description = 'command.restart.description'
CMD.syntax = 'command.restart.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 0
CMD.alias = 'maprestart'

--- Restarts the current map after an optional delay, saving data first, and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param delay=0 [String delay in seconds]
function CMD:on_run(actor, delay)
  delay = tonumber(delay) or 0

  self:notify_staff('command.restart.message', {
    player = get_player_name(actor),
    delay = delay
  })

  timer.Simple(delay, function()
    --- Run on the server by the Restart command right before the map is reloaded, so that
    -- everything is saved first. This is the hook Flux also runs from its periodic save; the
    -- gamemode's handler saves the config and runs the `SaveData` hook.
    hook.Run('FLSaveData')
    --- Called on the server when the Restart command is about to reload the map, after the
    -- `FLSaveData` hook has run. The gamemode's handler saves the data of every player.
    hook.Run('ServerRestart')

    RunConsoleCommand('changelevel', game.GetMap())
  end)
end
