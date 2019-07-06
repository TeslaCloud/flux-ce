COMMAND.name = 'Unban'
COMMAND.description = 'command.unban.description'
COMMAND.syntax = 'command.unban.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.administration'
COMMAND.arguments = 1
COMMAND.alias = 'plyunban'

function COMMAND:on_run(player, steam_id)
  if isstring(steam_id) and steam_id != '' then
    local success, copy = Bolt:remove_ban(steam_id)

    if success then
      self:notify_staff('command.unban.message', {
        player = get_player_name(player),
        target = copy.name
      })
    else
      player:notify('error.not_banned', { steam_id = steam_id })
    end
  else
    player:notify('error.not_banned', { steam_id = steam_id })
  end
end
