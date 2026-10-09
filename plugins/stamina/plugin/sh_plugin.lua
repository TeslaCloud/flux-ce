--- Stamina limits how long players can sprint.
-- Running drains the player's stamina and jumping costs a flat amount of it; once it
-- runs low the player can no longer run or jump properly. Stamina regenerates after a
-- short delay when the player stops running. The rates are set through the `stam_`
-- config keys, and other plugins can scale them per player through the
-- `StaminaAdjustDrainScale` and `StaminaAdjustRegenScale` hooks, or stop the stamina of a
-- player from changing through the `PlayerShouldStaminaDrain` and
-- `PlayerShouldStaminaRegenerate` hooks. Stamina never drains for players who are
-- noclipping or in observer mode.
--
-- Further `stam_` config keys, all off by default, make wounded players tire faster, let
-- crouching players recover faster, slow a running player down gradually as the stamina runs
-- out and save the stamina with the character instead of refilling it whenever a character
-- is loaded. The saved value is kept in the generic data of the character under the
-- `stamina` key, which needs the Characters plugin.
-- @module [Stamina]

PLUGIN:set_global('Stamina')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
