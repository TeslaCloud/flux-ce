local COMMAND = Command.new('unban')
COMMAND.name = 'Unban'
COMMAND.description = 'command.unban.description'
COMMAND.syntax = 'command.unban.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.administration'
COMMAND.arguments = 1
COMMAND.aliases = { 'plyunban' }

function COMMAND:on_run(player, steam_id)
  if isstring(steam_id) and steam_id != '' then
    local success, copy = Bolt:remove_ban(steam_id)

    if success then
      Flux.Player:broadcast('command.unban.message', {
        admin = get_player_name(player),
        target = copy.name
      })
    else
      player:notify('error.not_banned', steam_id)
    end
  end
end

COMMAND:register()
