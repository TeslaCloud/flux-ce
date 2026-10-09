--- Spawn Saver puts a character back where it was when its player left.
-- Whenever a character is saved, the position and the eye angles of its player are written
-- into the generic data of the character together with the name of the map. When the
-- character is loaded again on the same map, its player is moved to that spot right after
-- they have spawned. If something stands in the way they are moved to the nearest free spot;
-- if the spot is outside of the world, or nothing around it is free, they stay at the
-- regular spawn point.
--
-- A player in observer mode, in noclip or lying ragdolled is not where their character
-- would be expected, so nothing is written for them and the spot of the last save stays. A
-- character whose player is dead forgets its spot and starts at a regular spawn point next
-- time. Plugins change these rules with the `ShouldSavePlayerSpawn` and
-- `ShouldRestorePlayerSpawn` hooks.
--
-- The 'spawn_where_left' config turns all of this on and off. While it is off, characters
-- forget their spots as they are saved.
--
-- The spot is kept in the character data under the 'spawn_point' key, as a table with the
-- fields `map`, `position` and `angles`; `SpawnSaver:get_spawn_point` returns it.
-- @module [SpawnSaver]

PLUGIN:set_global('SpawnSaver')

require_relative 'sv_plugin'
require_relative 'sv_hooks'
