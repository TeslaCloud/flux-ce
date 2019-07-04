local COMMAND = Command.new('demote')
COMMAND.name = 'Demote'
COMMAND.description = 'demote.description'
COMMAND.syntax = 'demote.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.character_management'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'plydemote', 'chardemote' }

function COMMAND:on_run(player, targets)
  for k, v in ipairs(targets) do
    v:demote_rank()
  end

  Flux.Player:broadcast('demote.message', { get_player_name(player), util.player_list_to_string(targets) })
end

COMMAND:register()
