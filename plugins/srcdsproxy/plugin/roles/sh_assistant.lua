--- Adds the proxy commands for staff to the `assistant` role, and through it to every role
-- based on it: GList, which lists the players of the whole network, PInfo, which shows the
-- proxy's details on a player, and Transfer, which moves players to another server.

--- Allows the plugin's staff commands.
function ROLE:define_permissions()
  can 'glist'
  can 'pinfo'
  can 'transfer'
end
