CMD.name = 'DemoteRank'
CMD.description = 'command.demoterank.description'
CMD.syntax = 'command.demoterank.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'plydemoterank', 'chardemoterank' }

function CMD:on_run(player, targets)
  self:notify_staff('command.demoterank.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })

  for k, v in ipairs(targets) do
    v:demote_rank()
    v:notify('notification.demote_rank', { rank = v:get_rank_name() }, Color('salmon'))
  end
end
