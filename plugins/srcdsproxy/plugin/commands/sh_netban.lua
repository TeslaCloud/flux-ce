--- The NetBan command bans players, SteamIDs, IP addresses or subnets from the whole proxy
-- network, for good or for a duration such as `30m`, `2h`, `7d` or `1w`, with an optional
-- reason, and the proxy kicks whoever the ban covers. Only proxy admins can use it. The
-- player is a name or a target selector for players on this server, who have to pass the
-- caller's immunity check, or a name, SteamID, IP address or subnet for everybody else.

CMD.name = 'NetBan'
CMD.description = 'command.netban.description'
CMD.syntax = 'command.netban.syntax'
CMD.category = 'permission.categories.proxy'
CMD.arguments = 1
CMD.aliases = { 'proxyban' }
CMD.no_console = true

--- Has the proxy ban the targets from the network and notifies staff. A second argument that
-- is not a duration is the first word of the reason.
-- @param actor [Player the caller]
-- @param target [String player name, target selector, SteamID, address or subnet]
-- @param duration=nil [String ban duration, or the first word of the reason]
-- @param ... [Vararg words of the reason]
function CMD:on_run(actor, target, duration, ...)
  local reason = table.concat({ ... }, ' ')
  local entries = SrcdsProxy:ban(actor, 'ban', target, duration, reason)

  if !entries then return end

  local details = table.concat({ duration, ... }, ' ')

  self:notify_staff('command.netban.message', {
    player = get_player_name(actor),
    target = SrcdsProxy:targets_to_string(entries),
    details = details != '' and details or 'ui.no_reason'
  })
end
