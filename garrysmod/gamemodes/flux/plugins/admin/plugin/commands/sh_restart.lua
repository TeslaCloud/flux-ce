local COMMAND = Command.new('restart')
COMMAND.name = 'Restart'
COMMAND.description = 'restart.description'
COMMAND.syntax = 'restart.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'categories.server_management'
COMMAND.arguments = 0
COMMAND.aliases = { 'maprestart' }

function COMMAND:on_run(player, delay)
  delay = tonumber(delay) or 0

  Flux.Player:broadcast('map_restart_message', { get_player_name(player), delay })

  timer.Simple(delay, function()
    hook.run('FLSaveData')
    hook.run('ServerRestart')

    RunConsoleCommand('changelevel', game.GetMap())
  end)
end

COMMAND:register()
