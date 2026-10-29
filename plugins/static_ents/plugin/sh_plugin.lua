--- Static Entities lets staff make entities persistent, so that they are saved with the map
-- and spawned again when it loads.
-- Entities are made static or unstatic with the `static add` and `static remove` commands or
-- with the Static Add/Remove tool, which all go through the `PlayerSetEntityStatic` hook. Only
-- whitelisted classes can be made static: props, ragdolls, lights and lamps by default, and
-- whatever plugins add with `StaticEnts:whitelist_ent`. The plugin turns Sandbox's own
-- persistence off and saves and loads through the `PersistenceSave` and `PersistenceLoad`
-- hooks instead. The `fl_persistence_backup` console command, open to the console and to the
-- players with the 'static' permission, writes a copy of all persistent entities to the plugin
-- data of the current schema and map, under 'static_backups/<timestamp>'; a player can run it
-- once every 30 seconds.

PLUGIN:set_global('StaticEnts')

require_relative 'cl_plugin'
require_relative 'sv_hooks'
require_relative 'sv_plugin'

--- Registers the 'static_tool' permission.
function StaticEnts:RegisterPermissions()
  Bolt:register_permission('static_tool', nil, nil, 'permission.categories.level_design')
end
