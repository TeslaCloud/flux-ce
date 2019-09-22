CMD.name = 'KickBots'
CMD.description = 'command.kickbots.description'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.aliases = { 'botkick', 'kickbot' }

function CMD:on_run(player)
  self:notify_staff('command.kickbots.message', {
    player = get_player_name(player)
  })

  for k, v in ipairs(_player.all()) do
    if v:IsBot() then
      v:Kick('Kicking bots')
    end
  end
end
