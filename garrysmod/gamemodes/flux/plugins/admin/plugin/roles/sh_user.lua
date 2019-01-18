ROLE.name = 'User'
ROLE.description = t'role.user'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'icon16/user.png'
ROLE.immunity = 0

function ROLE:define_permissions()
  can 'test'
end

-- Called when player's primary group is being set to this group.
function ROLE:on_group_set(player, previous_group) end

-- Called when player's primary group is taken or modified.
function ROLE:on_group_taken(player, new_group) end
