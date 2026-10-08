--- The Demote command sets the role of the targeted players back to `user`. By default only
-- administrators can use it.

CMD.name = 'Demote'
CMD.description = 'command.demote.description'
CMD.syntax = 'command.demote.syntax'
CMD.permission = 'administrator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.alias = 'plydemote'

--- Demotes the targeted players to the 'user' role and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to demote]
function CMD:on_run(actor, targets)
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
end
