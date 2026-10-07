CMD.name = 'KickBots'
CMD.description = 'command.kickbots.description'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.aliases = { 'botkick', 'kickbot' }

--- Kicks every bot from the server and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
function CMD:on_run(actor)
  self:notify_staff('command.kickbots.message', {
    player = get_player_name(actor)
  })

  for k, v in ipairs(player.GetAll()) do
    if v:IsBot() then
      v:Kick('Kicking bots')
    end
  end
end
