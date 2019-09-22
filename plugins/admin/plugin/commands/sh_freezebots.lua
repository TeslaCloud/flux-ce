CMD.name = 'FreezeBots'
CMD.description = 'command.freezebots.description'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.aliases = { 'botfreeze', 'freezebot', 'bot_freeze', 'bot_zombie' }

function CMD:on_run(player)
  self:notify_staff('command.freezebots.message', {
    player = get_player_name(player)
  })

  RunConsoleCommand('bot_zombie', 1)
end
