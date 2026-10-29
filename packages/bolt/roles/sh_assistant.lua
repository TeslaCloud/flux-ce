--- The Assistant role (`assistant`): the first staff role, based on `user`, with an immunity
-- of 100. This file defines the role's default permissions on top of those of `user`: the
-- physics and tool guns, spawning props and entities, the context menu, observer mode and
-- the admin ESP, the level design tools that place texts, containers, doors, static entities
-- and vendors, and the commands that moderate players and characters. Other addons see
-- assistants as admins through the `moderate` permission.

ROLE.name = 'Assistant'
ROLE.description = 'role.assistant'
ROLE.color = Color(255, 255, 255)
ROLE.icon = 'fa-user-plus'
ROLE.immunity = 100
ROLE.base = 'user'

--- Allows the role's default permissions.
function ROLE:define_permissions()
  can 'staff'
  can 'moderate'

  can 'physgun'
  can 'physgun_freeze'
  can 'toolgun'
  can 'context_menu'
  can 'noclip'
  can 'admin_esp'
  can 'view_damage_logs'
  can 'bypass_chat_cooldown'
  can 'manage_ranks'

  can 'spawn_props'
  can 'spawn_chairs'
  can 'spawn_entities'
  can 'spawn_ragdolls'

  can 'texts'
  can 'pictures'
  can 'manage_containers'
  can 'manage_doors'
  can 'static_tool'
  can 'manage_vendors'

  can 'announce'
  can 'warn'
  can 'kick'
  can 'ban'
  can 'freeze'
  can 'godmode'
  can 'vanish'
  can 'slay'
  can 'respawn'
  can 'tp'
  can 'tpto'
  can 'send'
  can 'return'

  can 'charban'
  can 'charsetname'
  can 'charsetdesc'
  can 'charsetgender'
  can 'charsetmodel'
  can 'attribute_list'
  can 'level_get'
  can 'serverlevel_get'
  can 'charclearrecognition'
  can 'charforget'
  can 'heallimbs'
  can 'setfaction'
  can 'rank_set'

  can 'forcefall'
  can 'forcegetup'
  can 'knockout'

  can 'event'
  can 'eventlocal'
  can 'gag'
  can 'itsremove'

  can 'static'
end
