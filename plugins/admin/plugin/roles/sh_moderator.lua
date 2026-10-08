--- The Moderator role (`moderator`): based on `assistant`, with an immunity of 200. It
-- defines no permissions itself and has those registered for `moderator` and for the roles
-- it is based on.

ROLE.name = 'Moderator'
ROLE.description = 'role.moderator'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user-tie'
ROLE.immunity = 200
ROLE.base = 'assistant'

--- Defines the role's permissions. Empty: moderators only have what is registered for the
-- 'moderator' role and what they inherit from 'assistant'.
function ROLE:define_permissions()
end
