local COMMAND = Command.new('promoterank')
COMMAND.name = 'PromoteRank'
COMMAND.description = 'command.promoterank.description'
COMMAND.syntax = 'command.promoterank.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'plypromoterank', 'charpromoterank' }

function COMMAND:on_run(player, targets)
  self:notify_staff('command.promoterank.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })

  for k, v in ipairs(targets) do
    v:promote_rank()
    v:notify('notification.promote_rank', { rank = v:get_rank_name() }, Color('lightgreen'))
  end
end

COMMAND:register()
