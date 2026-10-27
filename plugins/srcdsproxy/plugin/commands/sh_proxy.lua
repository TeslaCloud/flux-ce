--- The Proxy command tells the caller whether they are connected through the proxy and how
-- the proxy knows them: the server of the network they are on, their SteamID64 and whether
-- Steam has verified it, the address they connect from, the version of the proxy, and
-- whether they are a proxy admin.

CMD.name = 'Proxy'
CMD.description = 'command.proxy.description'
CMD.category = 'permission.categories.proxy'
CMD.aliases = { 'proxystatus' }
CMD.no_console = true

--- Tells the caller in notifications how the proxy knows them, or that they are connected
-- to this server directly.
-- @param actor [Player the caller]
function CMD:on_run(actor)
  if !SrcdsProxy:check_available(actor) then return end

  if !Proxy.is_proxied(actor) then
    actor:notify('command.proxy.not_proxied')

    return
  end

  local steam_id = Proxy.claimed_steamid64(actor)

  actor:notify('command.proxy.backend', {
    backend = Proxy.backend_name(actor),
    version = actor:GetInfo('srcdsproxy_version')
  })

  if steam_id == '' or steam_id == '0' then
    actor:notify('command.proxy.no_steamid')
  elseif Proxy.steam_verified(actor) then
    actor:notify('command.proxy.steamid_verified', { steamid = steam_id })
  else
    actor:notify('command.proxy.steamid_claimed', { steamid = steam_id })
  end

  actor:notify('command.proxy.address', { address = Proxy.real_ip(actor) })

  if Proxy.is_proxy_admin(actor) then
    actor:notify('command.proxy.proxy_admin')
  end
end
