CMD.name = 'Unban'
CMD.description = 'command.unban.description'
CMD.syntax = 'command.unban.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.alias = 'plyunban'

--- Lifts the ban on a SteamID and notifies staff, or tells the caller that it is not banned.
-- @param player [Player the caller, or an invalid entity when run from the server console]
-- @param steam_id [String SteamID to unban]
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
