COMMAND.name = 'SetRank'
COMMAND.description = 'command.setrank.description'
COMMAND.syntax = 'command.setrank.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'plysetrank', 'charsetrank' }

function COMMAND:on_run(player, targets, rank)
  rank = tonumber(rank)

  if !rank then
    player:notify('error.invalid_value')
    
    return
  end

  self:notify_staff('command.setrank.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    rank = rank
  })

  for k, v in ipairs(targets) do
    local faction_table = v:get_faction()
    local rank_table = faction_table:get_rank(rank)

    if rank_table then
      v:set_rank(rank)
      v:notify('notification.rank_changed', { rank = rank_table.id })
    end
  end
end
