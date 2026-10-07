CMD.name = 'UnfreezeBots'
CMD.description = 'command.unfreezebots.description'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.aliases = { 'botunfreeze', 'unfreezebot', 'bot_unfreeze', 'bot_unzombie' }

--- Unfreezes all bots by turning bot_zombie off and notifies staff.
-- @param player [Player the caller, or an invalid entity when run from the server console]
function CMD:on_run(player)
  self:notify_staff('command.unfreezebots.message', {
    player = get_player_name(player)
  })

  RunConsoleCommand('bot_zombie', 0)
end
