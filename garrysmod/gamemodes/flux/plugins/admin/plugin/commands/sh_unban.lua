local COMMAND = Command.new('unban')
COMMAND.name = 'Unban'
COMMAND.description = t'unbancmd.description'
COMMAND.syntax = t'unbancmd.syntax'
COMMAND.category = 'categories.administration'
COMMAND.arguments = 1
COMMAND.aliases = { 'plyunban' }

function COMMAND:on_run(player, steam_id)
  if isstring(steam_id) and steam_id != '' then
    local success, copy = Bolt:remove_ban(steam_id)

    if success then
      fl.player:broadcast('unban_message', {
        admin = get_player_name(player),
        target = copy.name
      })
    else
      player:notify('err.not_banned', steam_id)
    end
  end
end

COMMAND:register()
