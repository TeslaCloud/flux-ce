CMD.name = 'Fullbright'
CMD.description = 'command.fullbright.description'
CMD.syntax = 'command.fullbright.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.immunity = true
CMD.alias = 'fb'

function CMD:on_run(player, targets, should_fullbright)
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
