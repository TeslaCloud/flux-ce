CMD.name = 'Kick'
CMD.description = 'command.kick.description'
CMD.syntax = 'command.kick.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.immunity = true
CMD.alias = 'plykick'

function CMD:on_run(player, targets, ...)
  local reason = table.concat({ ... }, ' ')

  if !reason or reason == '' then
    reason = 'ui.no_reason'
  end

  for k, v in ipairs(targets) do
    v:Kick(reason)
  end

  self:notify_staff('command.kick.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    reason = reason
  })
end
