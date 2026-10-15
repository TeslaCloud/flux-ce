--- The User role (`user`): the role of every player who has not been given another one,
-- with an immunity of 0. This file defines the role's default permissions: the commands
-- every player may run, such as the roleplay commands, rolling dice, falling over, handing
-- out money and moving members of their faction up and down its ranks. Every other role is
-- based on this one and has these permissions too.

ROLE.name = 'User'
ROLE.description = 'role.user'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user'
ROLE.immunity = 0

--- Allows the role's default permissions.
function ROLE:define_permissions()
  can 'me'
  can 'it'
  can 'its'
  can 'whisper'
  can 'yell'
  can 'roll'

  can 'charphysdesc'
  can 'fall'
  can 'getup'

  can 'dropmoney'
  can 'givemoney'

  can 'rank'
end

--- Called when the player's primary group is being set to this group.
-- @param _target [Player]
-- @param _previous_group [Role the player's previous role]
function ROLE:on_role_set(_target, _previous_group) end

--- Called when the player's primary group is taken or modified.
-- @param _target [Player]
-- @param _new_group [Role the role the player is being given]
function ROLE:on_role_taken(_target, _new_group) end
