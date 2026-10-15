--- The Transfer command moves players to another server of the proxy network, with an
-- optional reason. The player is the exact name or a target selector of players on this
-- server, or a name or SteamID for players on other servers. Players on this server have to
-- pass the caller's immunity check.
--
-- A caller who is connected through the proxy has the proxy move the targets, which works
-- for players on every server of the network, and lets a proxy admin send players into
-- whitelist-only servers. The server console, and a caller who is not connected through the
-- proxy, can only move players who are on this server.

CMD.name = 'Transfer'
CMD.description = 'command.transfer.description'
CMD.syntax = 'command.transfer.syntax'
CMD.category = 'permission.categories.proxy'
CMD.arguments = 2
CMD.arg_types = { 'player', 'server', 'text' }
CMD.player_arg = false
CMD.aliases = { 'proxysend' }

--- Moves the targeted players to the named server and notifies staff. The proxy answers the
-- commands it is sent in the caller's console; if the server refuses a player, the proxy
-- sends them back.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param target [String player name, target selector or SteamID]
-- @param server [String name of the server to move the players to]
-- @param ... [Vararg words of the reason]
function CMD:on_run(actor, target, server, ...)
  if !SrcdsProxy:check_available(actor) then return end

  local name = SrcdsProxy:server_name(server)

  if !name then
    Flux.Player:notify(actor, 'error.proxy.server_invalid', { server = tostring(server) })

    return
  end

  local reason = table.concat({ ... }, ' ')
  local entries = SrcdsProxy:find_targets(actor, target, true)

  if !entries then return end

  local moved = {}

  if srcdsproxy.IsProxied(actor) then
    local verbs = {}

    for k, v in ipairs(entries) do
      verbs[#verbs + 1] = SrcdsProxy:verb('send', v.id, name, reason)
    end

    if !SrcdsProxy:run(actor, verbs) then return end

    moved = entries
  else
    for k, v in ipairs(entries) do
      if IsValid(v.player) then
        if srcdsproxy.Transfer(v.player, name, reason != '' and reason or nil) then
          moved[#moved + 1] = v
        end
      else
        Flux.Player:notify(actor, 'error.proxy.remote_target', { target = v.id })
      end
    end
  end

  if #moved == 0 then return end

  self:notify_staff('command.transfer.message', {
    player = get_player_name(actor),
    target = SrcdsProxy:targets_to_string(moved),
    server = name,
    reason = reason != '' and reason or 'ui.no_reason'
  })
end
