--- The Bots command manages the bots of the server: `/bots add [amount]` adds bots (1 by
-- default, 128 at most), `/bots kick` kicks every bot, and `/bots freeze` and `/bots unfreeze`
-- freeze and unfreeze all bots through the `bot_zombie` console variable. Every subcommand
-- needs the `bots` permission.

CMD.name = 'Bots'
CMD.description = 'command.bots.description'
CMD.category = 'permission.categories.server_management'
CMD.aliases = { 'bot' }

local add = CMD:subcommand('add')
add.description = 'command.bots.add.description'
add.syntax = 'command.bots.add.syntax'
add.arg_types = { 'number' }

--- Adds bots to the server, one every 0.2 seconds, and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param amount=1 [String number of bots to add, clamped to 1-128]
function add:on_run(actor, amount)
  amount = math.clamp((tonumber(amount) or 1), 1, 128)

  self:notify_staff('command.bots.add.message', {
    player = get_player_name(actor),
    amount = amount
  })

  timer.Create('fl_add_bots', 0.2, amount, function()
    RunConsoleCommand('bot')
  end)
end

local kick = CMD:subcommand('kick')
kick.description = 'command.bots.kick.description'

--- Kicks every bot from the server and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
function kick:on_run(actor)
  self:notify_staff('command.bots.kick.message', {
    player = get_player_name(actor)
  })

  for _, v in player.Iterator() do
    if v:IsBot() then
      v:Kick('Kicking bots')
    end
  end
end

local freeze = CMD:subcommand('freeze')
freeze.description = 'command.bots.freeze.description'

--- Freezes all bots by turning bot_zombie on and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
function freeze:on_run(actor)
  self:notify_staff('command.bots.freeze.message', {
    player = get_player_name(actor)
  })

  RunConsoleCommand('bot_zombie', 1)
end

local unfreeze = CMD:subcommand('unfreeze')
unfreeze.description = 'command.bots.unfreeze.description'

--- Unfreezes all bots by turning bot_zombie off and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
function unfreeze:on_run(actor)
  self:notify_staff('command.bots.unfreeze.message', {
    player = get_player_name(actor)
  })

  RunConsoleCommand('bot_zombie', 0)
end
