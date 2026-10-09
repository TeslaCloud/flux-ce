--- Player extensions of the Ragdoll plugin that work on both realms: reading the ragdoll
-- state of a player and finding the ragdoll that stands in for them. The state and the
-- ragdoll are data table variables of the player, so a client knows them for every player it
-- is being sent.
-- @module [Player]

local player_meta = FindMetaTable('Player')

--- Returns the ragdoll state of the player.
-- @return [Number one of the RAGDOLL_ enums, RAGDOLL_NONE if the player is not ragdolled]
function player_meta:get_ragdoll_state()
  return self:GetDTInt(INT_RAGDOLL_STATE) or RAGDOLL_NONE
end

--- Returns the player's ragdoll entity: the body of a player who has fallen over or was
-- knocked out, or the corpse of a dead one.
-- @return [Entity the ragdoll, or a NULL entity if the player has none]
function player_meta:get_ragdoll_entity()
  return self:GetDTEntity(ENT_RAGDOLL)
end

--- Checks whether the player is in any ragdoll state other than RAGDOLL_NONE. Note that this
-- includes dead players, who are in the RAGDOLL_DUMMY state until they respawn.
-- @return [Boolean]
function player_meta:is_ragdolled()
  return self:get_ragdoll_state() != RAGDOLL_NONE
end

--- Checks whether the player is lying on the ground and able to get up by themselves.
-- @return [Boolean]
function player_meta:is_fallen_over()
  return self:get_ragdoll_state() == RAGDOLL_FALLENOVER
end

--- Checks whether the player is knocked out: lying on the ground, unable to get up until
-- the state ends.
-- @return [Boolean]
function player_meta:is_knocked_out()
  return self:get_ragdoll_state() == RAGDOLL_KNOCKEDOUT
end

--- Returns how long the knocked out player stays out, for HUDs and the like. Both realms
-- know it, as the end of the get up timer is networked.
-- @return [Number seconds until the player comes to by themselves; 0 if they are not
--   knocked out; nil if they are knocked out without a timer, or while the timer is paused,
--   and stay out until something wakes them]
function player_meta:get_knockout_remaining()
  if !self:is_knocked_out() then return 0 end

  local getup_end = self:get_nv('ragdoll_getup_end')

  if !isnumber(getup_end) then return end

  return math.max(getup_end - CurTime(), 0)
end
