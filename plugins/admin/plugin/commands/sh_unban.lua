CMD.name = 'Unban'
CMD.description = 'command.unban.description'
CMD.syntax = 'command.unban.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.alias = 'plyunban'

function CMD:on_run(player, steam_id)
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
