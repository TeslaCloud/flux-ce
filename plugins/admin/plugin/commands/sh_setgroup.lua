COMMAND.name = 'SetGroup'
COMMAND.description = 'command.setgroup.description'
COMMAND.syntax = 'command.setgroup.syntax'
COMMAND.permission = 'administrator'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = { 'plysetgroup', 'setusergroup', 'plysetusergroup' }

function COMMAND:get_description()
  local groups = {}

  for k, v in pairs(Bolt:get_roles()) do
    table.insert(groups, k)
  end

  return t(self.description, { groups = table.concat(groups, ', ') })
end

function COMMAND:on_run(player, targets, role)
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
