--- The `proxywhitelist` command works with the whitelists of the whitelist-only servers of
-- the proxy network, which the proxy keeps in its admins.toml. Only proxy admins can use it.
-- `/proxywhitelist add <server> <player>` and `/proxywhitelist remove <server> <player>` add
-- players to the whitelist of a server or remove them from it, and `/proxywhitelist list
-- [server]` has the proxy list the whitelists, or the one of a server, in the caller's
-- console. The player is the exact name or a target selector of players on this server, or a
-- name, `#id` or SteamID in any of the forms admins.toml takes for everybody else, who need
-- not be online.

CMD.name = 'ProxyWhitelist'
CMD.description = 'command.proxywhitelist.description'
CMD.category = 'permission.categories.proxy'
CMD.aliases = { 'netwhitelist', 'pwl' }
CMD.no_console = true

--- Adds the targeted players to or removes them from the whitelist of a server and notifies
-- staff.
-- @param cmd [Command the subcommand that runs]
-- @param actor [Player the caller]
-- @param action [String 'add' or 'remove']
-- @param server [String name of the server whose whitelist to edit]
-- @param target [String player name, target selector, `#id` or SteamID]
local function edit_whitelist(cmd, actor, action, server, target)
  if !SrcdsProxy:require_proxy_admin(actor) then return end

  local entries = SrcdsProxy:find_targets(actor, target)

  if !entries then return end

  local verbs = {}

  for _, entry in ipairs(entries) do
    verbs[#verbs + 1] = SrcdsProxy:verb('whitelist '..action, server, entry.id)
  end

  if !SrcdsProxy:run(actor, verbs) then return end

  cmd:notify_staff('command.proxywhitelist.'..action..'.message', {
    player = get_player_name(actor),
    target = SrcdsProxy:targets_to_string(entries),
    server = server
  })
end

local add = CMD:subcommand('add')
add.description = 'command.proxywhitelist.add.description'
add.syntax = 'command.proxywhitelist.add.syntax'
add.arguments = 2
add.arg_types = { 'server', 'player' }
add.player_arg = false

--- Adds the targeted players to the whitelist of a server and notifies staff.
-- @param actor [Player the caller]
-- @param server [String name of the server]
-- @param target [String player name, target selector, `#id` or SteamID]
function add:on_run(actor, server, target)
  edit_whitelist(self, actor, 'add', server, target)
end

local remove = CMD:subcommand('remove')
remove.description = 'command.proxywhitelist.remove.description'
remove.syntax = 'command.proxywhitelist.remove.syntax'
remove.arguments = 2
remove.arg_types = { 'server', 'player' }
remove.player_arg = false

--- Removes the targeted players from the whitelist of a server and notifies staff.
-- @param actor [Player the caller]
-- @param server [String name of the server]
-- @param target [String player name, target selector, `#id` or SteamID]
function remove:on_run(actor, server, target)
  edit_whitelist(self, actor, 'remove', server, target)
end

local list_cmd = CMD:subcommand('list')
list_cmd.description = 'command.proxywhitelist.list.description'
list_cmd.syntax = 'command.proxywhitelist.list.syntax'
list_cmd.arg_types = { 'server' }

--- Has the proxy list the whitelists, or the one of a server, in the caller's console.
-- @param actor [Player the caller]
-- @param server=nil [String name of the server whose whitelist to list]
function list_cmd:on_run(actor, server)
  if !SrcdsProxy:require_proxy_admin(actor) then return end

  SrcdsProxy:run(actor, SrcdsProxy:verb('whitelist list', server))
end
