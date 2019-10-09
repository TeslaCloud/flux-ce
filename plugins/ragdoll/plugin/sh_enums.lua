-- Can't use enumerate here since this is made to avoid collisions with legacy DTVars...
ENT_RAGDOLL         = 2 -- Player's ragdoll (E.G. fallenover, death or anything else).

enumerate 'INT_RAGDOLL_STATE'
-- INT_RAGDOLL_STATE   = Player's ragdoll state (RAGDOLL_ enums).

-- Ragdoll states
enumerate 'RAGDOLL_NONE RAGDOLL_FALLENOVER RAGDOLL_DUMMY'
-- RAGDOLL_NONE        = Not ragdolled.
-- RAGDOLL_FALLENOVER  = Ragdolled and can take damage.
-- RAGDOLL_DUMMY       = Ragdolled and cannot take damage.
