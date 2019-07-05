local COMMAND = Command.new('demote')
COMMAND.name = 'Demote'
COMMAND.description = 'command.demote.description'
COMMAND.syntax = 'command.demote.syntax'
COMMAND.permission = 'administrator'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'plydemote' }

function COMMAND:on_run(player, targets)
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

COMMAND:register()
