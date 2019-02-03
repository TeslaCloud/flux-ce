local COMMAND = Command.new('setgroup')
COMMAND.name = 'SetGroup'
COMMAND.description = t'set_group.description'
COMMAND.syntax = t'set_group.syntax'
COMMAND.permission = 'administrator'
COMMAND.category = 'categories.player_management'
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = { 'plysetgroup', 'setusergroup', 'plysetusergroup' }

function COMMAND:on_run(player, targets, role)
  if Bolt:group_exists(role) then
    for k, v in ipairs(targets) do
      v:SetUserGroup(role)
    end

    fl.player:broadcast('set_group.message', { get_player_name(player), util.player_list_to_string(targets), role })
  else
    player:notify('err.group_not_valid', role)
  end
end

COMMAND:register()
