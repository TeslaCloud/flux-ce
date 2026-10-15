--- The PInfo command has the proxy show its details on players of any server of the network
-- in the caller's console. The player is a name or a target selector for players on this
-- server, or a name, SteamID or `#id` from GList for players on other servers.

CMD.name = 'PInfo'
CMD.description = 'command.pinfo.description'
CMD.syntax = 'command.pinfo.syntax'
CMD.category = 'permission.categories.proxy'
CMD.arguments = 1
CMD.aliases = { 'proxyinfo' }
CMD.no_console = true

--- Has the proxy show its details on every targeted player in the caller's console.
-- @param actor [Player the caller]
-- @param target [String player name, target selector, SteamID or `#id`]
function CMD:on_run(actor, target)
  if !SrcdsProxy:check_proxied(actor) then return end

  local entries = SrcdsProxy:find_targets(actor, target)

  if !entries then return end

  local verbs = {}

  for k, v in ipairs(entries) do
    verbs[#verbs + 1] = SrcdsProxy:verb('info', v.id)
  end

  SrcdsProxy:run(actor, verbs)
end
