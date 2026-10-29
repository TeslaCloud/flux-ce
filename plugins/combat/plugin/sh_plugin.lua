--- The turn based combat. A `Combat` holds the players and NPCs who fight each other, in the
-- order of their initiative, and gives each of them a turn in that order, round after round:
-- the others stay frozen, a player has 60 seconds, an attack turn and two move turns (a
-- weapon item may set its own number of attack turns with a `turns` field), and an NPC acts
-- for 4 seconds. Walking uses up the move turns, attacking, switching weapons and reloading
-- the attack turns, using or moving an item a move turn. A player ends their turn with the
-- Show Help key (F1), and one who has not acted yet in it tries to leave the combat, which a
-- hit interrupts. A combat ends when nobody is left who is willing to fight.
--
-- Every attack between a player and an NPC, or between two players, is an attack roll of the
-- D20 plugin, see `CombatSystem:calculate_hit`; a miss deals no damage.
-- With the 'combat_auto_start' config on, such an attack between two entities that are not in
-- a combat starts one with everybody the two of them can see nearby. With it off, which is
-- the default, combat starts only through `CombatSystem:start_combat`; attacks still join and
-- roll in a combat that is running.
--
-- Plugins change the fight through the `AdjustAttackDistance`, `AdjustCombatTurnOrder` and
-- `AdjustPlayerTurns` hooks, and through the hooks of the D20 plugin.
-- @module [CombatSystem]

PLUGIN:set_global 'CombatSystem'

require_relative 'cl_hooks'
require_relative 'sv_hooks'
