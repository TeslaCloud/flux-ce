--- The Gamemaster role (`gamemaster`): based on `assistant`, with an immunity of 200. It
-- defines no permissions itself and has those registered for `gamemaster` and for the roles
-- it is based on: the tools that run the game world, such as spawning NPCs and vehicles,
-- handing out items and money, and managing areas, map scenes and spawn points.

ROLE.name = 'Gamemaster'
ROLE.description = 'role.gamemaster'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-hat-wizard'
ROLE.immunity = 200
ROLE.base = 'assistant'

--- Defines the role's permissions. Empty: gamemasters only have what is registered for the
-- 'gamemaster' role and what they inherit from 'assistant'.
function ROLE:define_permissions()
end
