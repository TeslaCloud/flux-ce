--- SrcdsProxy connects Flux to srcdsproxy, the proxy that lets players move between the
-- servers of a network without reconnecting. Every server of the network runs the proxy's
-- backend addon, whose `srcdsproxy` Lua table talks to the proxy; this plugin turns that
-- addon's player and admin commands into Flux commands, so that Bolt's role files decide who
-- may run them, and they are logged, find their targets and check immunity like every other
-- command.
--
-- Players see how the proxy knows them with Proxy and move themselves with Server, while
-- the server allows it (`srcdsproxy_allow_player_transfer`). Staff list the players of the
-- whole network with GList, look one up with PInfo and move players with Transfer. The proxy
-- itself restricts the rest to its own admins (listed in its admins.toml and verified by
-- Steam): ProxyWhitelist edits the whitelists of whitelist-only servers, and NetBan, NetBanIP,
-- NetUnban and NetBans manage the bans of the whole network. A player argument is a name, a
-- target selector or a SteamID for players on this server, while the proxy's `#id` session
-- IDs, IP addresses and subnets, and the names and SteamIDs of players on other servers go to
-- the proxy as typed. Commands that check immunity do not take a `#id` from players.
-- The proxy answers most commands in the console of the player who has run them.
--
-- Once the gamemode has initialized, the plugin turns off the chat commands of the addon and
-- replaces its `srcdsproxy_*` console commands with ones that run the matching Flux commands.
-- It also answers the addon's admin check with the `moderate` permission. Without the addon
-- the plugin does nothing but print a warning, and its commands tell the caller that the
-- addon is missing.
-- @module [SrcdsProxy]

PLUGIN:set_global('SrcdsProxy')

require_relative 'sv_plugin'
require_relative 'sv_hooks'
