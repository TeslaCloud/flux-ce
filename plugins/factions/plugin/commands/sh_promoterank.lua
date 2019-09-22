CMD.name = 'PromoteRank'
CMD.description = 'command.promoterank.description'
CMD.syntax = 'command.promoterank.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'plypromoterank', 'charpromoterank' }

function CMD:on_run(player, targets)
  self:notify_staff('command.promoterank.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })

  for k, v in ipairs(targets) do
    v:promote_rank()
    v:notify('notification.promote_rank', { rank = v:get_rank_name() }, Color('lightgreen'))
  end
end
