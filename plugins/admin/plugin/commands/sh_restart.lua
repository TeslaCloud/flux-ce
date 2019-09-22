CMD.name = 'Restart'
CMD.description = 'command.restart.description'
CMD.syntax = 'command.restart.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 0
CMD.alias = 'maprestart'

function CMD:on_run(player, delay)
  delay = tonumber(delay) or 0

  self:notify_staff('command.restart.message', {
    player = get_player_name(player),
    delay = delay
  })

  timer.simple(delay, function()
    hook.run('FLSaveData')
    hook.run('ServerRestart')

    RunConsoleCommand('changelevel', game.GetMap())
  end)
end
