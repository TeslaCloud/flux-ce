--- The Gamemaster role (`gamemaster`): based on `assistant`, with an immunity of 200. This
-- file defines the role's default permissions on top of those of `assistant`: the tools that
-- run the game world, such as gamemaster mode, spawning NPCs, vehicles, weapons and items,
-- picking up any entity, handing out items and money, setting the time, the health, the armor
-- and the stats of characters, whitelisting players and managing areas, map scenes, spawn
-- points and container loot.
-- Other addons see gamemasters as super admins through the `administrate` permission.

ROLE.name = 'Gamemaster'
ROLE.description = 'role.gamemaster'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-hat-wizard'
ROLE.immunity = 200
ROLE.base = 'assistant'

--- Allows the role's default permissions.
function ROLE:define_permissions()
  can 'administrate'
  can 'gamemastery'

  can 'physgun_pickup'
  can 'bypass_prop_protection'

  can 'spawn_vehicles'
  can 'spawn_npcs'
  can 'spawn_sweps'

  can 'manage_areas'
  can 'manage_map_scenes'
  can 'manage_spawn_points'
  can 'fill_containers'

  can 'bots'
  can 'fullbright'
  can 'settime'
  can 'sethealth'
  can 'setarmor'

  can 'gmpossess'
  can 'gmrelease'

  can 'giveitem'
  can 'give_items'
  can 'spawn_items'
  can 'setmoney'
  can 'whitelist'

  can 'attribute'
  can 'charsetskill'
end
