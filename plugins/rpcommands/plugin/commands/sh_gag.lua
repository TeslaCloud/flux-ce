--- The `gag` staff command: mutes players in the OOC and LOOC chats for a time. The mute is
-- kept in the player data as a real time, so it lasts through restarts and reconnects.

CMD.name = 'Gag'
CMD.description = 'command.gag.description'
CMD.syntax = 'command.gag.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'muteooc', 'oocmute', 'plygag' }

--- Mutes the target players in OOC chat for a duration and notifies them and the staff. A
-- duration that is not a time, or that comes to nothing (0 or 'permanent', which a ban time
-- reads as 0), is refused: a mute always has an end.
-- @param actor [Player player running the command; not valid when run from the server console]
-- @param targets [List<Player> players to gag]
-- @param duration [String gag duration, parsed like a ban time]
function CMD:on_run(actor, targets, duration, ...)
  local reason = table.concat({ ... }, ' ')
  local entered = tostring(duration):gsub('%%', '')

  duration = Bolt:interpret_ban_time(duration)

  if !reason or reason == '' then
    reason = 'ui.no_reason'
  end

  if !isnumber(duration) or duration != duration or duration <= 0 or duration == math.huge then
    Flux.Player:notify(actor, 'error.invalid_time', {
      time = entered
    })

    return
  end

  for k, v in ipairs(targets) do
    RPCommands:set_ooc_mute(v, duration)
    v:notify('notification.muted', { time = Flux.Lang:duration(duration) })
  end

  self:notify_staff('command.gag.message', {
    admin = get_player_name(actor),
    target = util.player_list_to_string(targets),
    time = Flux.Lang:duration(duration),
    reason = reason
  })
end
