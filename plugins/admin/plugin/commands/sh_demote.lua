--- The Demote command sets the role of the targeted players back to `user`. Given a SteamID
-- that belongs to nobody on the server, it changes the role that is stored for that SteamID
-- instead, so that staff members can be demoted while they are away. By default only
-- administrators can use it.
--
-- The command finds its targets itself instead of setting `immunity`, because the command
-- interpreter only knows the players who are on the server.

CMD.name = 'Demote'
CMD.description = 'command.demote.description'
CMD.syntax = 'command.demote.syntax'
CMD.permission = 'admin'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.alias = 'plydemote'

--- Demotes the targeted players, or the owner of a SteamID who is not on the server, to the
-- 'user' role and notifies them and staff. The caller needs a higher immunity than every
-- target; for a SteamID that goes by the role stored for it.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param target [String player name, target selector or SteamID]
function CMD:on_run(actor, target)
  local targets, steam_id = Bolt:find_command_targets(actor, target)

  if targets then
    for k, v in ipairs(targets) do
      v:notify('notification.demote', {
        group = v:GetUserGroup()
      })
      v:SetUserGroup('user')
    end

    self:notify_staff('command.demote.message', {
      player = get_player_name(actor),
      target = util.player_list_to_string(targets)
    })
  elseif steam_id then
    Bolt:demote_steam_id(actor, steam_id, function(name)
      self:notify_staff('command.demote.message', {
        player = get_player_name(actor),
        target = name
      })
    end)
  end
end
