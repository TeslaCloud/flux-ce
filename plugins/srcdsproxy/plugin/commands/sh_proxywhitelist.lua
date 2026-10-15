--- The ProxyWhitelist command edits the whitelists of the whitelist-only servers of the
-- proxy network, which the proxy keeps in its admins.toml, or lists them in the caller's
-- console. Only proxy admins can use it. The player to add or remove is a name or a target
-- selector for players on this server, or a name, `#id` or SteamID in any of the forms
-- admins.toml takes for everybody else, who need not be online.

CMD.name = 'ProxyWhitelist'
CMD.description = 'command.proxywhitelist.description'
CMD.syntax = 'command.proxywhitelist.syntax'
CMD.category = 'permission.categories.proxy'
CMD.aliases = { 'netwhitelist', 'pwl' }
CMD.no_console = true

--- Adds the targeted players to or removes them from the whitelist of a server and notifies
-- staff, or has the proxy list the whitelists, or the one of a server, in the caller's
-- console. Without arguments it lists them all.
-- @param actor [Player the caller]
-- @param action='list' [String 'add', 'remove' or 'list']
-- @param server=nil [String name of the server whose whitelist to edit or list]
-- @param target=nil [String player name, target selector, `#id` or SteamID; needed for 'add'
--   and 'remove']
function CMD:on_run(actor, action, server, target)
  if !SrcdsProxy:require_proxy_admin(actor) then return end

  action = string.lower(action or 'list')

  if action == 'list' then
    SrcdsProxy:run(actor, SrcdsProxy:verb('whitelist list', server))

    return
  end

  if (action != 'add' and action != 'remove') or !server or !target then
    actor:notify('error.command.syntax', { command = self.name, syntax = self.syntax })

    return
  end

  local entries = SrcdsProxy:find_targets(actor, target)

  if !entries then return end

  local verbs = {}

  for k, v in ipairs(entries) do
    verbs[#verbs + 1] = SrcdsProxy:verb('whitelist '..action, server, v.id)
  end

  if !SrcdsProxy:run(actor, verbs) then return end

  local message = action == 'add' and 'command.proxywhitelist.message_add' or 'command.proxywhitelist.message_remove'

  self:notify_staff(message, {
    player = get_player_name(actor),
    target = SrcdsProxy:targets_to_string(entries),
    server = server
  })
end
