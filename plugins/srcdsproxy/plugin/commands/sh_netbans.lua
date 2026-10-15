--- The NetBans command has the proxy list the bans of the network, and whom they cover right
-- now, in the caller's console. Only proxy admins can use it.

CMD.name = 'NetBans'
CMD.description = 'command.netbans.description'
CMD.category = 'permission.categories.proxy'
CMD.aliases = { 'proxybans' }
CMD.no_console = true

--- Has the proxy list the bans of the network in the caller's console.
-- @param actor [Player the caller]
function CMD:on_run(actor)
  if !SrcdsProxy:require_proxy_admin(actor) then return end

  SrcdsProxy:run(actor, 'bans')
end
