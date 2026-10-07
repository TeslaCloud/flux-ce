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

  timer.simple(delay, function()
    hook.run('FLSaveData')
    hook.run('ServerRestart')

    RunConsoleCommand('changelevel', game.GetMap())
  end)
end
