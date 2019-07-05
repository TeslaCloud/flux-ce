local COMMAND = Command.new('demoterank')
COMMAND.name = 'DemoteRank'
COMMAND.description = 'command.demoterank.description'
COMMAND.syntax = 'command.demoterank.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'plydemoterank', 'chardemoterank' }

function COMMAND:on_run(player, targets)
  for k, v in ipairs(targets) do
    v:demoterank_rank()
  end

  self:notify_staff('demoterank.message', { get_player_name(player), util.player_list_to_string(targets) })
end

COMMAND:register()
