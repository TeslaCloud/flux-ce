ROLE.name = 'Moderator'
ROLE.description = t'role.moderator'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'icon16/star.png'
ROLE.immunity = 200
ROLE.base = 'assistant'

function ROLE:define_permissions()
  can 'noclip'
  can 'moderate'
  can('manage', User)
  can('manage', Ban)
  can('manage', Character)
end
