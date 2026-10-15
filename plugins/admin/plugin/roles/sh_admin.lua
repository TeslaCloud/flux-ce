--- The Administrator role (`admin`): based on `gamemaster`, with an immunity of 300. This
-- file defines the role's default permissions. `allow_anything` already lets administrators
-- do anything; the permissions listed after it are the defaults that stop at this role: the
-- configuration, the permission editor and the plugin manager, and the commands that manage
-- roles, permissions, levels and the server.

ROLE.name = 'Administrator'
ROLE.description = 'role.admin'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user-shield'
ROLE.immunity = 300
ROLE.base = 'gamemaster'

--- Lets administrators do anything, and names the permissions that no lower role has by
-- default.
function ROLE:define_permissions()
  allow_anything()

  can 'manage_configuration'
  can 'manage_permissions'
  can 'manage_plugins'

  can 'setgroup'
  can 'demote'
  can 'grant'
  can 'revoke'
  can 'resetpermission'
  can 'permissions'

  can 'changelevel'
  can 'restart'

  can 'chargiveexperience'
  can 'charsetlevel'
  can 'setserverlevel'
end
