COMMAND.name = 'Fullbright'
COMMAND.description = 'command.fullbright.description'
COMMAND.syntax = 'command.fullbright.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = { 'fb' }

function COMMAND:on_run(player, targets, should_fullbright)
  should_fullbright = tobool(should_fullbright)

  for k, v in ipairs(targets) do
    v:set_nv('should_fullbright', should_fullbright)
    v:notify('notification.fullbright.'..(should_fullbright and 'enabled' or 'disabled'))
  end

  self:notify_staff('command.fullbright.'..(should_fullbright and 'enabled' or 'disabled'), {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
