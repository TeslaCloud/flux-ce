local COMMAND = Command.new('ban')
COMMAND.name = 'Ban'
COMMAND.description = 'command.ban.description'
COMMAND.syntax = 'command.ban.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.administration'
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = { 'plyban' }

function COMMAND:on_run(player, targets, duration, ...)
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

COMMAND:register()
