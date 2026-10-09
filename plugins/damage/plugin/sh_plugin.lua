--- Damage adds configurable rules to the damage players take, and to how they recover.
-- Everything is set through the config keys of the `damage` category, and with the default
-- values the plugin changes nothing about the game.
--
-- Hits are multiplied by hit location (`damage_scale_head`, `damage_scale_chest`,
-- `damage_scale_stomach`, `damage_scale_arms`, `damage_scale_legs`) and falls by
-- `damage_scale_fall`. The multipliers are applied to the damage in place, on top of whatever
-- the gamemode, the schema and other plugins do in their own `ScalePlayerDamage`,
-- `FLGetFallDamage` and `EntityTakeDamage` handlers: the handlers of the plugin return
-- nothing, so the others still run. `health_regen` slowly heals hurt players, `drowning` hurts
-- players who stay under water for too long, `damage_view_punch` jolts the view of a player
-- who is hurt, and `log_damage` and `log_kills` write the damage players take and their
-- deaths to the log; staff with the 'view_damage_logs' permission see these entries in
-- their console.
--
-- Other plugins take part through hooks. `PrePlayerTakeDamage` runs before a player takes
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
    'permission.categories.administration',
    'assistant'
  )
end
