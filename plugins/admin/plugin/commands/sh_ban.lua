CMD.name = 'Ban'
CMD.description = 'command.ban.description'
CMD.syntax = 'command.ban.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 2
CMD.immunity = true
CMD.alias = 'plyban'

function CMD:on_run(player, targets, duration, ...)
  local reason = table.concat({ ... }, ' ')

  if !reason or reason == '' then
    reason = 'ui.no_reason'
  end

  duration = Bolt:interpret_ban_time(duration)

  if !isnumber(duration) then
    player:notify('error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  for k, v in ipairs(targets) do
    Bolt:ban(v, duration, reason)
  end

  self:notify_staff('command.ban.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    time = Flux.Lang:nice_time(duration),
    reason = reason
  })
end
