--- The User role (`user`): the role of every player who has not been given another one,
-- with an immunity of 0. It defines no permissions itself and has those registered for
-- `user`.

ROLE.name = 'User'
ROLE.description = 'role.user'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user'
ROLE.immunity = 0

--- Defines the role's permissions. Empty: users only have what is registered for the 'user'
-- role.
function ROLE:define_permissions()
end

--- Called when the player's primary group is being set to this group.
-- @param target [Player]
-- @param previous_group [Role the player's previous role]
function ROLE:on_role_set(target, previous_group) end

--- Called when the player's primary group is taken or modified.
-- @param target [Player]
-- @param new_group [Role the role the player is being given]
function ROLE:on_role_taken(target, new_group) end
