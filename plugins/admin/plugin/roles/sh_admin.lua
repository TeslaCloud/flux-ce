--- The Administrator role (`admin`): based on `moderator`, with an immunity of 300 and every
-- permission allowed.

ROLE.name = 'Administrator'
ROLE.description = 'role.admin'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user-shield'
ROLE.immunity = 300
ROLE.base = 'moderator'

--- Allows administrators to do anything.
function ROLE:define_permissions()
  allow_anything()
end
