--- The Administrator role (`admin`): based on `gamemaster`, with an immunity of 300 and every
-- permission allowed, including the configuration, permissions, plugins and the commands
-- that manage roles and the server.

ROLE.name = 'Administrator'
ROLE.description = 'role.admin'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user-shield'
ROLE.immunity = 300
ROLE.base = 'gamemaster'

--- Allows administrators to do anything.
function ROLE:define_permissions()
  allow_anything()
end
