--- The Ban command bans the targeted players for a duration such as `30` (minutes),
-- `2 hours` or `perma`, with an optional reason, and kicks them. Allowed for assistants by
-- default.

CMD.name = 'Ban'
CMD.description = 'command.ban.description'
CMD.syntax = 'command.ban.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 2
CMD.immunity = true
CMD.alias = 'plyban'

--- Bans the targeted players for the given duration and notifies staff. A duration of 0 is a
-- permanent ban and is announced as one.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to ban]
-- @param duration [String ban length as read by Bolt:interpret_ban_time, e.g. '30' or 'perma']
-- @param ... [Vararg words of the ban reason]
function CMD:on_run(actor, targets, duration, ...)
  local reason = table.concat({ ... }, ' ')

  if !reason or reason == '' then
    reason = 'ui.no_reason'
  end

  duration = Bolt:interpret_ban_time(duration)

  if !isnumber(duration) then
    actor:notify('error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  for k, v in ipairs(targets) do
    Bolt:ban(v, duration, reason)
  end

  self:notify_staff(duration == 0 and 'command.ban.message_permanent' or 'command.ban.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    time = Flux.Lang:duration(duration),
    reason = reason
  })
end
