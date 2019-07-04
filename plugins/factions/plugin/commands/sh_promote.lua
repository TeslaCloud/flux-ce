local COMMAND = Command.new('promote')
COMMAND.name = 'Promote'
COMMAND.description = 'promote.description'
COMMAND.syntax = 'promote.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.character_management'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'plypromote', 'charpromote' }

function COMMAND:on_run(player, targets)
  for k, v in ipairs(targets) do
    v:promote_rank()
  end

  Flux.Player:broadcast('promote.message', { get_player_name(player), util.player_list_to_string(targets) })
end

COMMAND:register()
