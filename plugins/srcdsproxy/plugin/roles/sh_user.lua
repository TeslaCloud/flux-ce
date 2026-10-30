--- Adds the proxy commands every player may run to the `user` role, and through it to every
-- role based on it: Proxy, which shows how the proxy knows the player, and Server, which
-- moves them to another server of the network.

--- Allows the plugin's player commands.
function ROLE:define_permissions()
  can 'proxy'
  can 'server'
end
