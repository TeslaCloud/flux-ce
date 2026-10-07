CMD.name = 'AddBots'
CMD.description = 'command.addbots.description'
CMD.syntax = 'command.addbots.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 0
CMD.aliases = { 'bot', 'bots' }

--- Adds bots to the server, one every 0.2 seconds, and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param num_bots=1 [String number of bots to add, clamped to 1-128]
function CMD:on_run(actor, num_bots)
  num_bots = math.clamp((tonumber(num_bots) or 1), 1, 128)

  self:notify_staff('command.addbots.message', {
    player = get_player_name(actor),
    amount = num_bots,
    bots = num_bots == 1 and 'command.addbots.bot_one' or 'command.addbots.bot_many'
  })

  timer.create('fl_add_bots', 0.2, num_bots, function()
    RunConsoleCommand('bot')
  end)
end
