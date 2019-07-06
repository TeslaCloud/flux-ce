COMMAND.name = 'UnfreezeBots'
COMMAND.description = 'command.unfreezebots.description'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.aliases = { 'botunfreeze', 'unfreezebot', 'bot_unfreeze', 'bot_unzombie' }

function COMMAND:on_run(player)
  self:notify_staff('command.unfreezebots.message', {
    player = get_player_name(player)
  })

  RunConsoleCommand('bot_zombie', 0)
end
