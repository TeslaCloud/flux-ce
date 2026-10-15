--- The `gag` staff command: `/gag add <player> <duration> [reason]` mutes players in the OOC
-- and LOOC chats for a time, and `/gag remove <player>` lifts the mute. The mute is kept in
-- the player data as a real time, so it lasts through restarts and reconnects.

CMD.name = 'Gag'
CMD.description = 'command.gag.description'
CMD.category = 'permission.categories.administration'
CMD.aliases = { 'oocmute', 'plygag' }

local add = CMD:subcommand('add')
add.description = 'command.gag.add.description'
add.syntax = 'command.gag.add.syntax'
add.arguments = 2
add.arg_types = { 'player', 'duration', 'text' }
add.immunity = true

--- Mutes the target players in OOC chat for a duration and notifies them and the staff. A
-- duration that is not a time, or that comes to nothing (0 or 'permanent', which a ban time
-- reads as 0), is refused: a mute always has an end.
-- @param actor [Player player running the command; not valid when run from the server console]
-- @param targets [List<Player> players to gag]
-- @param duration [String gag duration, parsed like a ban time]
function add:on_run(actor, targets, duration, ...)
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

  for _, v in ipairs(targets) do
    RPCommands:set_ooc_mute(v, duration)
    v:notify('notification.muted', { time = Flux.Lang:duration(duration) })
  end

  self:notify_staff('command.gag.add.message', {
    admin = get_player_name(actor),
    target = util.player_list_to_string(targets),
    time = Flux.Lang:duration(duration),
    reason = reason
  })
end

local remove = CMD:subcommand('remove')
remove.description = 'command.gag.remove.description'
remove.syntax = 'command.gag.remove.syntax'
remove.arguments = 1
remove.arg_types = { 'player' }
remove.immunity = true

--- Lifts the OOC mute of the target players and notifies the staff.
-- @param actor [Player player running the command; not valid when run from the server console]
-- @param targets [List<Player> players to ungag]
function remove:on_run(actor, targets)
  for _, v in ipairs(targets) do
    RPCommands:set_ooc_mute(v)
    v:notify('notification.unmuted')
  end

  self:notify_staff('command.gag.remove.message', {
    admin = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
