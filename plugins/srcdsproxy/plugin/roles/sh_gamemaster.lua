--- Adds the proxy commands that edit the whitelists and the bans of the whole network to the
-- `gamemaster` role, and through it to every role based on it: ProxyWhitelist, NetBan,
-- NetBanIP, NetUnban and NetBans. The proxy only takes these commands from its own admins,
-- so a player needs to be one of them as well.

--- Allows the plugin's network administration commands.
function ROLE:define_permissions()
  can 'proxywhitelist'
  can 'netban'
  can 'netbanip'
  can 'netunban'
  can 'netbans'
end
