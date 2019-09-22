CMD.name = 'Demote'
CMD.description = 'command.demote.description'
CMD.syntax = 'command.demote.syntax'
CMD.permission = 'administrator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.alias = 'plydemote'

function CMD:on_run(player, targets)
  for k, v in ipairs(targets) do
    v:notify('notification.demote', {
      group = v:GetUserGroup()
    })
    v:SetUserGroup('user')
  end

  self:notify_staff('command.demote.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
