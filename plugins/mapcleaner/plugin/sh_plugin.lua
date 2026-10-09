--- Map Cleaner strips a map of the entities that get in the way of roleplay.
-- Once the map has loaded, and again after every map cleanup, the plugin removes the
-- entities created by the map whose class matches one of the patterns of the
-- 'remove_map_classes' config: health and suit chargers, weapons, ammo, health kits and
-- batteries by default. A pattern is an entity class in which `*` stands for any number of
-- characters, so `weapon_*` covers every weapon. The 'remove_map_physics' config adds the
-- physics props of the map (`prop_physics*`) to that and 'remove_map_vehicles' its vehicles
-- (`prop_vehicle*`, which includes the seats built into the map); both are off by default.
-- A change of these configs applies the next time the map is loaded or cleaned up.
--
-- Only entities created by the map are ever removed. Whatever players, the framework or
-- other plugins have spawned is left alone, and so is a weapon of the map that a player
-- has picked up.
--
-- The `MapCleanerShouldRemove` hook decides about single entities: a schema uses it to keep
-- an entity whose class is on the list, or to remove one that is not, which is how fixes for
-- a particular map are made. `PostMapClean` runs after every pass.
-- ```
-- function SCHEMA:MapCleanerShouldRemove(entity, ent_class, matched)
--   if ent_class == 'func_button' and entity:GetName() == 'gunstore' then
--     return true
--   end
-- end
-- ```
-- @module [MapCleaner]

PLUGIN:set_global('MapCleaner')

require_relative 'sv_plugin'
require_relative 'sv_hooks'
