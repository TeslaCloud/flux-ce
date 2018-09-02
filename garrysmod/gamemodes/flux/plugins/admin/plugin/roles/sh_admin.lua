ROLE.name = "Administrator"
ROLE.description = t('role.admin')
ROLE.color = Color(255, 255, 255)
ROLE.icon = "icon16/shield.png"
ROLE.immunity = 300
ROLE.base = "moderator"

function ROLE:define_permissions()
  allow_anything()
end
