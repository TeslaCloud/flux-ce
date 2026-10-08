--- Stamina limits how long players can sprint.
-- Running drains the player's stamina and jumping costs a flat amount of it; once it
-- runs low the player can no longer run or jump properly. Stamina regenerates after a
-- short delay when the player stops running. The rates are set through the `stam_`
-- config keys, and other plugins can scale them per player through the
-- `StaminaAdjustDrainScale` and `StaminaAdjustRegenScale` hooks.
-- @module [Stamina]

PLUGIN:set_global('Stamina')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
