--- D20 rolls dice for damage. Every hit on a player or an NPC deals the total of a dice
-- formula, rolled with `Dice.roll`, instead of the damage the engine has worked out, while
-- the 'd20_enabled' config is on.
--
-- The formula of a hit is the first of these that applies (`D20:get_damage_formula`):
--
-- 1. The `damage_dice` of the weapon item that a player attacker holds, such as
--    `ITEM.damage_dice = '1d8'`, as long as the damage comes from that weapon and not from a
--    projectile of its own (a grenade, a bolt, a rocket).
-- 2. The dice of the class of the weapon or projectile that has dealt the damage, by
--    `D20:get_weapon_dice`: the inflictor when it is an entity of its own, otherwise the
--    weapon the attacker holds. Players and NPCs holding the same weapon roll the same dice.
-- 3. The dice of the class of an NPC attacker, by `D20:get_npc_dice`, for NPCs that attack
--    with their own body.
-- 4. The damage type: 1d4 for burns, 1d12 for explosions, 1d10 for crushing blows. Fall
--    damage and drowning are left to their own rules (see below).
-- 5. The damage of the engine itself: 1d4 up to 10, 1d6 up to 20, 1d10 up to 40, 1d12 above
--    that, and the 'd20_default_dice' config (1d6) when the engine damage is 0.
--
-- The dice of the weapons that come with the game: fists and stunstick 1d4, crowbar, pistol
-- and SMG 1d6, .357, AR2 and shotgun 1d10, crossbow, RPG and grenades 1d12, and the same for
-- their projectiles. The dice of the NPCs that fight with their own body: zombies, fast
-- zombies and zombines 1d6, poison zombies 1d10, headcrabs 1d4, antlions 1d6, antlion guards
-- 1d12, manhacks 1d4, hunters 1d10 and striders 1d12. A schema changes and adds dice with
-- `D20:set_weapon_dice` and `D20:set_npc_dice`, and staff override them in game with the
-- 'd20_weapon_dice' and 'd20_npc_dice' configs, lists of entries like
-- `'weapon_pistol = 1d8'`.
-- ```
-- -- In the schema: a heavier pistol and a tougher zombie.
-- D20:set_weapon_dice('weapon_pistol', '1d8')
-- D20:set_npc_dice('npc_zombie', '2d6')
--
-- -- On a weapon item.
-- ITEM.damage_dice = '1d10 + strength'
-- ```
-- Formulas may use the variables `damage` (the damage of the engine), `level` (the level of
-- a player attacker, 1 for anybody else) and the stats of a player attacker by their ID,
-- such as `strength`; the `AdjustDamageDice` hook adds more or changes the formula before
-- the roll, and `PlayerDamageRolled` reports every result.
--
-- Damage events from the same attacker and inflictor that hit the same victim in the same
-- tick, such as the pellets of a shotgun or an explosion that touches several hitboxes, are
-- one attack: the first one rolls and the others are blocked. The rolled total is rounded,
-- and the hit location multipliers still apply to it. A hit on a player is rolled in the
-- `ResolvePlayerDamage` hook of the Damage plugin, so that the `PrePlayerTakeDamage` hook
-- and every damage handler after it see the rolled damage. Hits on players and on NPCs get
-- every multiplier that the `ScalePlayerDamage` or `ScaleNPCDamage` handlers of the Damage
-- plugin, of the schema and of the gamemode have applied to them, the 'damage_scale_'
-- configs and the `AdjustEntityDamageScale` hook included, as `Damage:get_damage_scale`
-- reports it.
--
-- Fall damage rolls the 'd20_fall_dice' config, `{steps}d6` by default, where `steps` is 1
-- for the slowest fall that hurts and grows by 1 for every 150 units per second of fall
-- speed above 250, through the `GetPlayerFallDamage` hook; the 'damage_scale_fall' config of the
-- Damage plugin still multiplies it. Drowning rolls the 'damage_drowning_damage' formula of the
-- Damage plugin (1d4).
--
-- NPCs have their maximum health multiplied by the 'd20_npc_health_scale' config (0.25) when
-- they spawn, as rolled hits deal far less than the weapons of the engine.
--
-- Attack rolls decide whether an attack hits at all, for the systems that ask (such as
-- turn-based combat): `D20:attack_roll` rolls a d20 plus the attack modifier of the attacker
-- (`D20:get_attack_modifier`: the marksmanship or close combat skill of a player, by the
-- weapon they hold, or the 'd20_npc_attack_bonus' config for NPCs) against the armor class
-- of the target. `Player:get_armor_class` is 10, plus the reflexes of the player, plus 2
-- while they wear armor, and the `AdjustArmorClass` hook changes it; NPCs have the
-- 'd20_npc_armor_class' config (12). A natural 20 always hits and a natural 1 always misses,
-- and the `AdjustAttackRoll` hook changes the formula or the armor class before the roll.
-- ```
-- local hit, result, armor_class = D20:attack_roll(attacker, target)
--
-- if hit then
--   attacker:notify(Dice.format(result)..' against '..armor_class..': a hit!')
-- end
-- ```
-- The level and the stats come from the Levels and Stats plugins when they are loaded; the
-- plugin works without them, with a level of 1 and modifiers of 0.
-- @module [D20]

if !D20 then
  PLUGIN:set_global('D20')
end

require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Checks whether dice damage is turned on, through the 'd20_enabled' config.
-- @return [Boolean]
function D20:is_enabled()
  return Config.get('d20_enabled', true) ? true : false
end
