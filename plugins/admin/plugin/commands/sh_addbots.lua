COMMAND.name = 'AddBots'
COMMAND.description = 'command.addbots.description'
COMMAND.syntax = 'command.addbots.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.arguments = 0
COMMAND.aliases = { 'bot', 'bots' }

function COMMAND:on_run(player, num_bots)
  num_bots = math.clamp((tonumber(num_bots) or 1), 1, 128)

  self:notify_staff('command.addbots.message', {
    player = get_player_name(player),
    amount = num_bots,
    bots = num_bots == 1 and 'command.addbots.bot_one' or 'command.addbots.bot_many'
  })

  timer.create('fl_add_bots', 0.2, num_bots, function()
    RunConsoleCommand('bot')
  end)
end
