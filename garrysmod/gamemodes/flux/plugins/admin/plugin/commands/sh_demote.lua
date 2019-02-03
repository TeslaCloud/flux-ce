local COMMAND = Command.new('demote')
COMMAND.name = 'Demote'
COMMAND.description = t'demote.description'
COMMAND.syntax = t'demote.syntax'
COMMAND.permission = 'administrator'
COMMAND.category = 'categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'plydemote' }

function COMMAND:on_run(player, targets)
  for k, target in ipairs(targets) do
    target:SetUserGroup('user')

    fl.player:broadcast('demote.message', { get_player_name(player), target:name(), target:GetUserGroup() })
  end
end

COMMAND:register()
