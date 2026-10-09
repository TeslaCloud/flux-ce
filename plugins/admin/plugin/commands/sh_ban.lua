--- The Ban command bans the targeted players for a duration such as `30` (minutes),
-- `2 hours` or `perma`, with an optional reason, and kicks them. Given a SteamID that belongs
-- to nobody on the server, it bans that SteamID, whether its owner has ever joined or not.
-- Allowed for assistants by default.
--
-- The command finds its targets itself instead of setting `immunity`, because the command
-- interpreter only knows the players who are on the server.

CMD.name = 'Ban'
CMD.description = 'command.ban.description'
CMD.syntax = 'command.ban.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 2
CMD.alias = 'plyban'

--- Bans the targeted players, or the SteamID of somebody who is not on the server, for the
-- given duration and notifies staff. A duration of 0 is a permanent ban and is announced as
-- one. The caller needs a higher immunity than every target: for a SteamID that goes by the
-- role stored for it, and a SteamID from the root_steamid config can only be banned by a
-- root player or from the server console.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param target [String player name, target selector or SteamID]
-- @param duration [String ban length as read by Bolt:interpret_ban_time, e.g. '30' or 'perma']
-- @param ... [Vararg words of the ban reason]
function CMD:on_run(actor, target, duration, ...)
  local reason = table.concat({ ... }, ' ')
  local ban_time = Bolt:interpret_ban_time(duration)

  if !reason or reason == '' then
    reason = 'ui.no_reason'
  end

  if !isnumber(ban_time) then
    Flux.Player:notify(actor, 'error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  local message = ban_time == 0 and 'command.ban.message_permanent' or 'command.ban.message'
  local targets, steam_id = Bolt:find_command_targets(actor, target)

  if targets then
    local names = util.player_list_to_string(targets)

    for k, v in ipairs(targets) do
      Bolt:ban(v, ban_time, reason, false, actor)
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
