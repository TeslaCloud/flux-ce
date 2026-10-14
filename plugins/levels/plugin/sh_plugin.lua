--- Levels gives every character a level, from 1 to the `levels_max_level` config (20), and
-- the experience it has gathered toward the next one. Each level takes the same amount of
-- experience, the `levels_experience_per_level` config (1000). Both are stored in the
-- `level` and `experience` columns of the character and networked to its owner alone, so
-- `Player:get_level`, `Player:get_experience` and `Player:get_experience_to_level` work on
-- the server and, for the local player, on the client.
--
-- Experience is given with `Player:give_experience`, which can raise or lower the level by
-- several steps at once, and staff use the CharGiveExperience, CharSetLevel and CharLevel
-- commands. When the `levels_combat_experience` config is on, players also gain experience
-- for the damage they deal to NPCs and other players (`levels_experience_per_damage`) and
-- for the NPCs they kill (`levels_experience_per_kill`, more for NPCs with more health); the
-- `AdjustCombatExperience` hook changes or cancels that experience. `PlayerExperienceChanged`
-- and `PlayerLevelChanged` report every change.
--
-- Every level after the first grants `levels_skill_points_per_level` skill points, and every
-- `levels_boost_every` levels grant `levels_boost_points` attribute points. The points that
-- are not spent yet are kept in the `skill_points` and `attribute_points` character data,
-- which the owner receives, and are spent one at a time with `Player:spend_skill_point` and
-- `Player:spend_attribute_point`, each raising a skill or a stat of the Attributes plugin by
-- one level. Clients ask for that with the `fl_levels_spend_skill` and
-- `fl_levels_spend_attribute` messages.
--
-- The maximum health of a character grows with its level and its endurance, see
-- `Levels:get_max_health`. The plugin applies it whenever one of them changes and when the
-- player spawns, and answers the `GetPlayerMaxHealth` hook of the Factions plugin with it,
-- so the maximum health of a faction never takes its place.
-- @module [Levels]

PLUGIN:set_global('Levels')

require_relative 'sv_hooks'
