--- The Ban command bans players and lifts bans.
-- `/ban add <target or SteamID> <duration> [reason]` bans the targeted players for a duration
-- such as `30` (minutes), `"2 hours"` or `perma`, with an optional reason, and kicks them.
-- Given a SteamID that belongs to nobody on the server, it bans that SteamID, whether its owner
-- has ever joined or not. `/ban remove <SteamID>` lifts the ban of a SteamID. Both need the
-- `ban` permission.
--
-- `ban add` finds its targets itself instead of setting `immunity`, because the command
-- interpreter only knows the players who are on the server.

local max_unban_time = 253402300799

CMD.name = 'Ban'
CMD.description = 'command.ban.description'
CMD.category = 'permission.categories.administration'
CMD.aliases = { 'plyban' }

local add = CMD:subcommand('add')
add.description = 'command.ban.add.description'
add.syntax = 'command.ban.add.syntax'
add.arguments = 2
add.arg_types = { 'player', 'duration', 'text' }
add.player_arg = false

--- Bans the targeted players, or the SteamID of somebody who is not on the server, for the
-- given duration and notifies staff. A duration of 0 is a permanent ban and is announced as
-- one; a negative duration, or one that would end the ban after the year 9999, is refused.
-- The caller needs a higher immunity than every target: for a SteamID that goes by the role
-- stored for it, and a SteamID from the root_steamid config can only be banned by a root
-- player or from the server console.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param target [String exact player name, target selector or SteamID]
-- @param duration [String ban length as read by Bolt:interpret_ban_time, e.g. '30' or 'perma']
-- @param reason=nil [String the ban reason, as it was typed]
function add:on_run(actor, target, duration, reason)
  local ban_time = Bolt:interpret_ban_time(duration)

  if !reason or reason == '' then
    reason = 'ui.no_reason'
  end

  if !isnumber(ban_time) or ban_time != ban_time or ban_time < 0 or os.time() + ban_time > max_unban_time then
    Flux.Player:notify(actor, 'error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  local message = ban_time == 0 and 'command.ban.add.message_permanent' or 'command.ban.add.message'
  local targets, steam_id = Bolt:find_command_targets(actor, target)

  if targets then
    local names = util.player_list_to_string(targets)

    for _, client in ipairs(targets) do
      Bolt:ban(client, ban_time, reason, false, actor)
    end

    self:notify_staff(message, {
      player = get_player_name(actor),
      target = names,
      time = Flux.Lang:duration(ban_time),
      reason = reason
    })
  elseif steam_id then
    Bolt:with_offline_target(actor, steam_id, function(user)
      Bolt:ban(steam_id, ban_time, reason, false, actor, user and user.name)

      self:notify_staff(message, {
        player = get_player_name(actor),
        target = user and user.name or steam_id,
        time = Flux.Lang:duration(ban_time),
        reason = reason
      })
    end)
  end
end

local remove = CMD:subcommand('remove')
remove.description = 'command.ban.remove.description'
remove.syntax = 'command.ban.remove.syntax'
remove.arguments = 1
remove.arg_types = { 'steamid' }

--- Lifts the ban on a SteamID, typed in any case and with any universe digit, and notifies
-- staff, or tells the caller that it is not banned.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param steam_id [String SteamID to unban]
function remove:on_run(actor, steam_id)
  steam_id = Bolt:normalize_steam_id(tostring(steam_id):upper())

  local success, copy = Bolt:remove_ban(steam_id)

  if success then
    self:notify_staff('command.ban.remove.message', {
      player = get_player_name(actor),
      target = copy.name
    })
  else
    Flux.Player:notify(actor, 'error.not_banned', { steam_id = steam_id })
  end
end
