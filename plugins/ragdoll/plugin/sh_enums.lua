--- Enumerations of the Ragdoll plugin: the `ENT_RAGDOLL` and `INT_RAGDOLL_STATE` data table
-- slots of the player, and the ragdoll states.
-- `ENT_RAGDOLL` is the entity slot that holds the player's ragdoll (fallen over, knocked out
-- or dead). It is a fixed number rather than an enumeration to avoid collisions with legacy
-- data table variables. `INT_RAGDOLL_STATE` is the integer slot that holds the state, which
-- is one of:
-- * `RAGDOLL_NONE`: not ragdolled.
-- * `RAGDOLL_FALLENOVER`: lying on the ground, able to get up by themselves.
-- * `RAGDOLL_DUMMY`: dead; the ragdoll is the corpse the player has left.
-- * `RAGDOLL_KNOCKEDOUT`: unconscious, unable to get up until the state ends.

ENT_RAGDOLL = 2

enumerate 'INT_RAGDOLL_STATE'

enumerate 'RAGDOLL_NONE RAGDOLL_FALLENOVER RAGDOLL_DUMMY RAGDOLL_KNOCKEDOUT'
