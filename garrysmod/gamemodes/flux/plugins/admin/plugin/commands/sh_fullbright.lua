local COMMAND = Command.new('fullbright')
COMMAND.name = 'Fullbright'
COMMAND.description = 'fullbright.description'
COMMAND.syntax = 'fullbright.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'categories.player_management'
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = { 'fb' }

function COMMAND:on_run(player, targets, should_fullbright)
  should_fullbright = tobool(should_fullbright)

  for k, target in ipairs(targets) do
    target:set_nv('should_fullbright', should_fullbright, target)
    target:notify('fullbright.'..(should_fullbright and 'enabled' or 'disabled')..'_self')
  end

  self:notify_admin('moderator', 'fullbright.'..(should_fullbright and 'enabled' or 'disabled'), {
    targets = util.player_list_to_string(targets),
    player_name = get_player_name(player)
  })
end

COMMAND:register()
