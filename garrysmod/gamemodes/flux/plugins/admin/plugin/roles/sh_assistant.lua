ROLE.name = 'Assistant'
ROLE.description = t'role.assistant'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'icon16/smile.png'
ROLE.immunity = 100
ROLE.base = 'user'

function ROLE:define_permissions()
  can 'noclip'
end
