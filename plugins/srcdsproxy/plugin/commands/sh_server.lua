--- The Server command moves the caller to another server of the proxy network, or lists the
-- servers in their console when no name is given. It only works while the server lets
-- players move themselves (`srcdsproxy_allow_player_transfer`).

CMD.name = 'Server'
CMD.description = 'command.server.description'
CMD.syntax = 'command.server.syntax'
CMD.category = 'permission.categories.proxy'
CMD.aliases = { 'servers' }
CMD.no_console = true

--- Moves the caller to the named server, or has the proxy list the servers in their console.
-- If the server refuses the caller, the proxy sends them back.
-- @param actor [Player the caller]
-- @param server=nil [String name of the server to move to]
function CMD:on_run(actor, server)
  if !SrcdsProxy:check_available(actor) then return end

  if !srcdsproxy.PlayerTransferAllowed() then
    actor:notify('error.proxy.transfer_disabled')

    return
  end

  if !SrcdsProxy:check_proxied(actor) then return end

  if server == nil or server == '' then
    SrcdsProxy:run(actor, 'servers')

    return
  end

  local name = SrcdsProxy:server_name(server)

  if !name then
    actor:notify('error.proxy.server_invalid', { server = tostring(server) })

    return
  end

  actor:notify('command.server.message', { server = name })

  srcdsproxy.Transfer(actor, name, 'player request')
end
