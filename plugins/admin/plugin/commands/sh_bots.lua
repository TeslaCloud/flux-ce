local COMMAND = Command.new('freezebots')
COMMAND.name = 'FreezeBots'
COMMAND.description = 'command.freezebots.description'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.aliases = { 'botfreeze', 'freezebot', 'bot_freeze', 'bot_zombie' }

function COMMAND:on_run(player)
  Flux.Player:broadcast('command.freezebots.message', get_player_name(player))

  RunConsoleCommand('bot_zombie', 1)
end

COMMAND:register()

local COMMAND = Command.new('unfreezebots')
COMMAND.name = 'UnfreezeBots'
COMMAND.description = 'command.unfreezebots.description'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.aliases = { 'botunfreeze', 'unfreezebot', 'bot_unfreeze', 'bot_unzombie' }

function COMMAND:on_run(player)
  Flux.Player:broadcast('command.unfreezebots.message', get_player_name(player))

  RunConsoleCommand('bot_zombie', 0)
end

COMMAND:register()

local COMMAND = Command.new('addbots')
COMMAND.name = 'AddBots'
COMMAND.description = 'command.addbots.description'
COMMAND.syntax = 'command.addbots.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.arguments = 0
COMMAND.aliases = { 'bot', 'bots' }

function COMMAND:on_run(player, num_bots)
  num_bots = math.Clamp((tonumber(num_bots) or 1), 1, 128)

  Flux.Player:broadcast('command.addbots.message', { get_player_name(player), num_bots, num_bots == 1 and 'command.addbots.bot_one' or 'command.addbots.bot_many' })

  timer.Create('fl_add_bots', 0.2, num_bots, function()
    RunConsoleCommand('bot')
  end)
end

COMMAND:register()

local COMMAND = Command.new('kickbots')
COMMAND.name = 'KickBots'
COMMAND.description = 'command.kickbots.description'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.server_management'
COMMAND.aliases = { 'botkick', 'kickbot' }

function COMMAND:on_run(player)
  Flux.Player:broadcast('command.kickbots.message', get_player_name(player))

  for k, v in ipairs(_player.GetAll()) do
    if v:IsBot() then
      v:Kick('Kicking bots')
    end
  end
end

COMMAND:register()
