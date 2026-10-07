--- Cancels the player's current action and puts them into the RAGDOLL_DUMMY state, which
-- leaves a corpse ragdoll.
-- @param player [Player]
function PLUGIN:PlayerDeath(player)
  player:reset_action()
  player:set_ragdoll_state(RAGDOLL_DUMMY)
end

--- Resets the player's ragdoll state to RAGDOLL_NONE when they spawn.
-- @param player [Player]
function PLUGIN:PlayerSpawn(player)
  player:set_ragdoll_state(RAGDOLL_NONE)
end

--- Runs the PlayerDeathThink hook for dead players that are ragdolled.
-- @param player [Player]
function PLUGIN:PlayerThink(player)
  if !player:Alive() and player:is_ragdolled() then
    hook.run('PlayerDeathThink', player)
  end
end

--- Passes damage dealt to a player's ragdoll on to that player.
-- @param entity [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
function PLUGIN:EntityTakeDamage(entity, damage_info)
  if entity:IsRagdoll() and IsValid(entity.player) then
    local player = entity.player
    player:TakeDamageInfo(damage_info)
  end
end
