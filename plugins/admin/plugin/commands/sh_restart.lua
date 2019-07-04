local COMMAND = Command.new('restart')
COMMAND.name = 'Restart'
COMMAND.description = 'command.restart.description'
COMMAND.syntax = 'command.restart.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.arguments = 0
COMMAND.aliases = { 'maprestart' }

function COMMAND:on_run(player, delay)
  delay = tonumber(delay) or 0

  Flux.Player:broadcast('command.restart.message', { get_player_name(player), delay })

  timer.Simple(delay, function()
    hook.run('FLSaveData')
    hook.run('ServerRestart')

    RunConsoleCommand('changelevel', game.GetMap())
  end)
end

COMMAND:register()
