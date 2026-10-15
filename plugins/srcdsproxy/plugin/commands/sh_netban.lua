--- The `netban` command manages the bans of the whole proxy network. Only proxy admins can
-- use it, and the proxy answers in the caller's console.
-- `/netban add <player|steamid|ip|subnet> [duration] [reason]` bans players, SteamIDs, IP
-- addresses or subnets, and `/netban addip <player> [duration] [reason]` bans the addresses of
-- players, which is the way to ban a player the proxy knows no SteamID of. Both ban for good
-- or for a duration such as `30m`, `2h`, `7d` or `1w`, and the proxy kicks whoever the ban
-- covers. The player is the exact name or a target selector of players on this server, who
-- have to pass the caller's immunity check, or a name or SteamID for players on other
-- servers. `/netban remove <steamid|ip|subnet>` lifts the ban that covers the SteamID, the
-- address or the subnet, and `/netban list` lists the bans and whom they cover right now.

CMD.name = 'NetBan'
CMD.description = 'command.netban.description'
CMD.category = 'permission.categories.proxy'
CMD.aliases = { 'proxyban' }
CMD.no_console = true

local add = CMD:subcommand('add')
add.description = 'command.netban.add.description'
add.syntax = 'command.netban.add.syntax'
add.arguments = 1
add.arg_types = { 'player', 'proxy_duration', 'text' }
add.player_arg = false

--- Has the proxy ban the targets from the network and notifies staff. A second argument that
-- is not a duration is the start of the reason.
-- @param actor [Player the caller]
-- @param target [String player name, target selector, SteamID, address or subnet]
-- @param duration=nil [String ban duration, or the start of the reason]
-- @param reason=nil [String the rest of the reason, as it was typed]
function add:on_run(actor, target, duration, reason)
  local entries = SrcdsProxy:ban(actor, 'ban', target, duration, reason)

  if !entries then return end

  local details = reason and duration..' '..reason or duration or ''

  self:notify_staff('command.netban.add.message', {
    player = get_player_name(actor),
    target = SrcdsProxy:targets_to_string(entries),
    details = details != '' and details or 'ui.no_reason'
  })
end

local addip = CMD:subcommand('addip')
addip.description = 'command.netban.addip.description'
addip.syntax = 'command.netban.addip.syntax'
addip.arguments = 1
addip.arg_types = { 'player', 'proxy_duration', 'text' }
addip.player_arg = false

--- Has the proxy ban the addresses of the targets from the network and notifies staff. A
-- second argument that is not a duration is the start of the reason.
-- @param actor [Player the caller]
-- @param target [String player name, target selector or SteamID]
-- @param duration=nil [String ban duration, or the start of the reason]
-- @param reason=nil [String the rest of the reason, as it was typed]
function addip:on_run(actor, target, duration, reason)
  local entries = SrcdsProxy:ban(actor, 'banip', target, duration, reason)

  if !entries then return end

  local details = reason and duration..' '..reason or duration or ''

  self:notify_staff('command.netban.addip.message', {
    player = get_player_name(actor),
    target = SrcdsProxy:targets_to_string(entries),
    details = details != '' and details or 'ui.no_reason'
  })
end

local remove = CMD:subcommand('remove')
remove.description = 'command.netban.remove.description'
remove.syntax = 'command.netban.remove.syntax'
remove.arguments = 1
remove.arg_types = { 'proxy_ban' }

--- Has the proxy lift the ban and notifies staff. The proxy answers in the caller's console,
-- also when nothing was banned.
-- @param actor [Player the caller]
-- @param target [String SteamID, IP address or subnet of the ban]
function remove:on_run(actor, target)
  if !SrcdsProxy:require_proxy_admin(actor) then return end

  if !SrcdsProxy:run(actor, SrcdsProxy:verb('unban', target)) then return end

  self:notify_staff('command.netban.remove.message', {
    player = get_player_name(actor),
    target = target
  })
end

local list_cmd = CMD:subcommand('list')
list_cmd.description = 'command.netban.list.description'

--- Has the proxy list the bans of the network in the caller's console.
-- @param actor [Player the caller]
function list_cmd:on_run(actor)
  if !SrcdsProxy:require_proxy_admin(actor) then return end

  SrcdsProxy:run(actor, 'bans')
end
