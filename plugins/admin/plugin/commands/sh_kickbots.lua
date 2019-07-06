COMMAND.name = 'KickBots'
COMMAND.description = 'command.kickbots.description'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.aliases = { 'botkick', 'kickbot' }

function COMMAND:on_run(player)
  self:notify_staff('command.kickbots.message', {
    player = get_player_name(player)
  })

  for k, v in ipairs(_player.all()) do
    if v:IsBot() then
      v:Kick('Kicking bots')
    end
  end
end
