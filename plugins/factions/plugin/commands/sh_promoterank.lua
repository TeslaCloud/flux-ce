local COMMAND = Command.new('promoterank')
COMMAND.name = 'PromoteRank'
COMMAND.description = 'command.promoterank.description'
COMMAND.syntax = 'command.promoterank.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'perm.categories.character_management'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'plypromoterank', 'charpromoterank' }

function COMMAND:on_run(player, targets)
  for k, v in ipairs(targets) do
    v:promoterank_rank()
  end

  Flux.Player:broadcast('promoterank.message', { get_player_name(player), util.player_list_to_string(targets) })
end

COMMAND:register()
