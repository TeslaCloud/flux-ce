COMMAND.name = 'DemoteRank'
COMMAND.description = 'command.demoterank.description'
COMMAND.syntax = 'command.demoterank.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'plydemoterank', 'chardemoterank' }

function COMMAND:on_run(player, targets)
  self:notify_staff('command.demoterank.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })

  for k, v in ipairs(targets) do
    v:demote_rank()
    v:notify('notification.demote_rank', { rank = v:get_rank_name() }, Color('salmon'))
  end
end
