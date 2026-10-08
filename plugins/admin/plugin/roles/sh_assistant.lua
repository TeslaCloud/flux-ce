--- The Assistant role (`assistant`): the first staff role, based on `user`, with an immunity
-- of 100. It defines no permissions itself and has those registered for `assistant` and
-- for `user`.

ROLE.name = 'Assistant'
ROLE.description = 'role.assistant'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user-plus'
ROLE.immunity = 100
ROLE.base = 'user'

--- Defines the role's permissions. Empty: assistants only have what is registered for the
-- 'assistant' role and what they inherit from 'user'.
function ROLE:define_permissions()
end
