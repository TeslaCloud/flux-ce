COMMAND.name = 'FreezeBots'
COMMAND.description = 'command.freezebots.description'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.aliases = { 'botfreeze', 'freezebot', 'bot_freeze', 'bot_zombie' }

function COMMAND:on_run(player)
  self:notify_staff('command.freezebots.message', {
    player = get_player_name(player)
  })

  RunConsoleCommand('bot_zombie', 1)
end
