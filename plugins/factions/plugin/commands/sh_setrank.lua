local COMMAND = Command.new('setrank')
COMMAND.name = 'SetRank'
COMMAND.description = 'command.set_rank.description'
COMMAND.syntax = 'command.set_rank.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'perm.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'plysetrank', 'charsetrank' }

function COMMAND:on_run(player, targets, rank)
  rank = tonumber(rank)

  for k, v in ipairs(targets) do
    local faction_table = v:get_faction()

    if faction_table:get_rank(rank) then
      v:set_rank(rank)
    end
  end

  Flux.Player:broadcast('set_rank.message', { get_player_name(player), util.player_list_to_string(targets), rank })
end

COMMAND:register()
