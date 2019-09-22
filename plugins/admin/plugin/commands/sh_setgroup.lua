CMD.name = 'SetGroup'
CMD.description = 'command.setgroup.description'
CMD.syntax = 'command.setgroup.syntax'
CMD.permission = 'administrator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'plysetgroup', 'setusergroup', 'plysetusergroup' }

function CMD:get_description()
  local groups = {}

  for k, v in pairs(Bolt:get_roles()) do
    table.insert(groups, k)
  end

  return t(self.description, { groups = table.concat(groups, ', ') })
end

function CMD:on_run(player, targets, role)
  if Bolt:group_exists(role) then
    for k, v in ipairs(targets) do
      v:notify('notification.setgroup', {
        group = role
      })
      v:SetUserGroup(role)
    end

    self:notify_staff('command.setgroup.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      group = role
    })
  else
    player:notify('error.group_not_valid', { group = role })
  end
end
