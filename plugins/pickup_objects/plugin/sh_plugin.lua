--- Pickup Objects lets players carry light physics objects in their hands, throw them and
-- drag ragdolls along the ground.
-- With the fists out, secondary attack picks up the entity the player is looking at, if it is
-- within two meters and no heavier than the mass limit of the player. While something is
-- held, secondary attack or reload lets go of it and primary attack throws it. With the
-- `pickup_drag_ragdolls` config turned on a ragdoll is not carried: whatever it weighs, it is
-- dragged by the limb the player has grabbed, for as long as they stay on foot with their
-- fists out. That includes the fallen players and the corpses of the Ragdoll plugin. A
-- ragdoll is grabbed as soon as the key is pressed, and the fists do not punch it. A player
-- whose ragdoll is being dragged takes no physics damage through the ragdoll and has the
-- `dragged` networked variable set to true; the Ragdoll plugin asks `Player:get_dragger` to
-- keep them from getting up in the meantime.
--
-- The plugin has three configs: `pickup_max_mass` (25) is the heaviest object a player can
-- carry, `pickup_throw_force` (1000) is the force of a throw, where 0 turns throwing off,
-- and `pickup_drag_ragdolls` (false) turns the dragging of ragdolls on.
--
-- Plugins take part through the `PlayerPickupObject`, `PlayerDropObject`,
-- `PlayerThrowObject`, `PlayerCanDragRagdoll` and `AdjustPickupMassLimit` hooks. What is held
-- and by whom is answered by `Player:get_holding_entity`, `Entity:get_holder` and
-- `Player:get_dragger`, and the functions of the `PickupObjects` global make a player pick
-- up, drop or throw an entity. All of it is serverside.
-- @module [PickupObjects]

PLUGIN:set_global('PickupObjects')

require_relative 'sv_plugin'
require_relative 'sv_hooks'
