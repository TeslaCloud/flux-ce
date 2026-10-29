--- Damage adds configurable rules to the damage players and NPCs take, and to how players
-- recover.
-- Everything is set through the config keys of the `damage` category, and with the default
-- values the plugin changes nothing about the game.
--
-- Hits are multiplied by hit location (`damage_scale_head`, `damage_scale_chest`,
-- `damage_scale_stomach`, `damage_scale_arms`, `damage_scale_legs`), the hits on NPCs too
-- while `damage_scale_npcs` is on, and falls by `damage_scale_fall`. The multipliers are
-- applied to the damage in place, on top of whatever the gamemode, the schema and other
-- plugins do in their own `ScalePlayerDamage`, `ScaleNPCDamage`, `GetPlayerFallDamage` and
-- `EntityTakeDamage` handlers: the handlers of the plugin return nothing, so the others still
-- run. `damage_health_regen` slowly heals hurt players, `damage_drowning` hurts players who stay under
-- water for too long with damage rolled from the `damage_drowning_damage` dice formula (1d4 by
-- default), `damage_view_punch` jolts the view of a player who is hurt, and `damage_log` and
-- `damage_log_kills` write the damage players take and their deaths to the log; staff with the
-- 'view_damage_logs' permission see these entries in their console.
--
-- The plugin owns the names of the hit locations on both realms: `Damage:get_limbs` lists
-- the limbs, `Damage:get_limb` tells the limb that a HITGROUP_ enum belongs to and
-- `Damage:get_limb_name` the phrase of its name. On the server, `Damage:get_hitgroup` tells
-- where a player or an NPC has been hit by the damage being processed and
-- `Damage:get_damage_scale` what every `ScalePlayerDamage` or `ScaleNPCDamage` handler has
-- multiplied that hit by.
--
-- Other plugins take part through hooks. `AdjustEntityDamageScale` multiplies the hits on
-- players and NPCs by location after the configs, `ResolvePlayerDamage` lets a plugin replace
-- the amount of any damage to a player before the fall damage multiplier and the other hooks
-- see it (the D20 plugin rolls dice there), `PrePlayerTakeDamage` runs before a player takes
-- damage and can change or cancel it, and `PostPlayerTakeDamage` runs once the damage has
-- been dealt. `PlayerCanRegenerateHealth` and `GetHealthRegeneration` control the health
-- regeneration of a player, and `PlayerCanDrown` exempts a player from drowning.
-- @module [Damage]

PLUGIN:set_global('Damage')

require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Registers the 'view_damage_logs' permission, which sends the damage and kill log entries
-- to the console of the player.
function Damage:RegisterPermissions()
  Bolt:register_permission(
    'view_damage_logs',
    'View damage logs',
    'Prints the damage and kill log entries to the console of the player.',
    'permission.categories.administration'
  )
end
