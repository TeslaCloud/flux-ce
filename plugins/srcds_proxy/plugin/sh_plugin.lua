--- SrcdsProxy connects Flux to srcdsproxy, the proxy that lets players move between the
-- servers of a network without reconnecting. Every server of the network runs the proxy's
-- backend addon, whose `Proxy` Lua table talks to the proxy; this plugin turns that
-- addon's player and admin commands into Flux commands, so that Bolt's role files decide who
-- may run them, and they are logged, find their targets and check immunity like every other
-- command.
--
-- Players see how the proxy knows them with the Proxy command and move themselves with
-- Server, while the server allows it (`srcdsproxy_allow_player_transfer`). Staff list the
-- players of the whole network with GList, look one up with PInfo and move players with
-- Transfer. The proxy itself restricts the rest to its own admins (listed in its admins.toml
-- and verified by Steam): `proxywhitelist add`, `remove` and `list` edit and show the
-- whitelists of whitelist-only servers, and `netban add`, `addip`, `remove` and `list` manage
-- the bans of the whole network. A player argument is the exact name, a target selector or a
-- SteamID of players on this server, while the proxy's `#id` session IDs, IP addresses and
-- subnets, and the names and SteamIDs of players on other servers go to the proxy as typed.
-- Commands that check immunity do not take a `#id` from players. Only the proxy knows the
-- names of the servers, so they are not completed.
-- The proxy answers most commands in the console of the player who has run them.
--
-- Once the gamemode has initialized, the plugin turns off the chat commands of the addon and
-- replaces its `srcdsproxy_*` console commands with ones that run the matching Flux commands.
-- It also answers the addon's admin check with the `moderate` permission. Without the addon
-- the plugin does nothing but print a warning, and its commands tell the caller that the
-- addon is missing.
--
-- Server transfer areas move players to another server of the network when they walk into
-- them. Staff draw one with the Server Transfer Area mode of the Area Tool and give it the
-- name of a server and a delay; a player who is connected through the proxy and stays in the
-- area for that many seconds, with a countdown on their HUD, is moved to that server, unless
-- it is whitelist-only and they may not enter it, which they are told. Leaving the area
-- cancels the countdown, and a player is moved once per entry. The
-- `ShouldProxyTransferPlayer` hook lets plugins keep a player from being moved.
-- @module [SrcdsProxy]

PLUGIN:set_global('SrcdsProxy')

--- Lists example values for the arguments of the 'proxy_duration' type, ban durations in the
-- form the proxy reads, see `SrcdsProxy:is_duration`.
-- @return [List<String> durations]
local function complete_proxy_duration()
  return { '30m', '2h', '1d', '7d', '1w', 'perm' }
end

Flux.Command:add_completer('proxy_duration', complete_proxy_duration)

require_relative 'sh_hooks'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
