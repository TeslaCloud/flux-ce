--- Server hooks of the Ragdoll plugin: ragdolls players when they die, resets them when they
-- spawn and passes the damage a ragdoll takes on to its player.

--- Cancels the player's current action and puts them into the RAGDOLL_DUMMY state, which
-- leaves a corpse ragdoll.
-- @param victim [Player]
function PLUGIN:PlayerDeath(victim)
  victim:reset_action()
  victim:set_ragdoll_state(RAGDOLL_DUMMY)
end

--- Resets the player's ragdoll state to RAGDOLL_NONE when they spawn.
-- @param actor [Player]
function PLUGIN:PlayerSpawn(actor)
  actor:set_ragdoll_state(RAGDOLL_NONE)
end

--- Runs the PlayerDeathThink hook for dead players that are ragdolled.
-- @param actor [Player]
function PLUGIN:PlayerThink(actor)
  if !actor:Alive() and actor:is_ragdolled() then
    --- GMod's `PlayerDeathThink` hook, run again by the Ragdoll plugin.
    -- Besides the engine's own calls, the plugin runs it on the server from its `PlayerThink`
    -- handler for every dead player who is ragdolled. This call ignores what the handlers
    -- return.
    -- @param actor [Player The dead player]
    hook.Run('PlayerDeathThink', actor)
  end
end

--- Passes damage dealt to a player's ragdoll on to that player.
-- @param entity [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
function PLUGIN:EntityTakeDamage(entity, damage_info)
  if entity:IsRagdoll() and IsValid(entity.player) then
    local owner = entity.player
    owner:TakeDamageInfo(damage_info)
  end
end
