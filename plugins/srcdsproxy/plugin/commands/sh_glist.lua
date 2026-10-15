--- The GList command has the proxy list every player of the network, on all of its servers,
-- in the caller's console: their session ID, name, SteamID, verification, server, state,
-- time and address.

CMD.name = 'GList'
CMD.description = 'command.glist.description'
CMD.category = 'permission.categories.proxy'
CMD.aliases = { 'proxyplayers' }
CMD.no_console = true

--- Has the proxy list the players of the network in the caller's console.
-- @param actor [Player the caller]
function CMD:on_run(actor)
  SrcdsProxy:run(actor, 'glist')
end
