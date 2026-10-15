--- The NetUnban command lifts a ban of the proxy network, given the SteamID, the IP address
-- or the subnet it covers. Only proxy admins can use it.

CMD.name = 'NetUnban'
CMD.description = 'command.netunban.description'
CMD.syntax = 'command.netunban.syntax'
CMD.category = 'permission.categories.proxy'
CMD.arguments = 1
CMD.aliases = { 'proxyunban' }
CMD.no_console = true

--- Has the proxy lift the ban and notifies staff. The proxy answers in the caller's console,
-- also when nothing was banned.
-- @param actor [Player the caller]
-- @param target [String SteamID, IP address or subnet of the ban]
function CMD:on_run(actor, target)
  if !SrcdsProxy:require_proxy_admin(actor) then return end

  if !SrcdsProxy:run(actor, SrcdsProxy:verb('unban', target)) then return end

  self:notify_staff('command.netunban.message', {
    player = get_player_name(actor),
    target = target
  })
end
