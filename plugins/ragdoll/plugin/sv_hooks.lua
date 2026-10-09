--- Server hooks of the Ragdoll plugin: ragdolls players when they die, resets them when they
-- spawn or leave, passes the damage a ragdoll takes on to its player, keeps the get up
-- timers running and makes players fall over from hard falls and heavy hits when the
-- config says so.

--- Cancels the player's current action and puts them into the RAGDOLL_DUMMY state, which
-- leaves a corpse ragdoll. The ragdoll of a player who died lying on the ground becomes
-- their corpse.
-- @param victim [Player]
function Ragdoll:PlayerDeath(victim)
  victim:reset_action()
  victim:set_ragdoll_state(RAGDOLL_DUMMY)
end

--- Clears the player's ragdoll state when they spawn. Their corpse stays for its decay time.
-- @param actor [Player]
function Ragdoll:PlayerSpawn(actor)
  actor:reset_ragdoll_state()
end

--- Lets go of the ragdoll of a player who is leaving, so that it is removed once the decay
-- time has passed rather than staying on the map.
-- @param actor [Player]
function Ragdoll:PlayerDisconnected(actor)
  local ragdoll = actor:get_ragdoll_entity()

  if IsValid(ragdoll) then
    ragdoll.decay = ragdoll.decay or Config.get('ragdoll_decay_time', 120)
  end

  actor:reset_ragdoll_state()
end

--- Runs the PlayerDeathThink hook for dead players that are ragdolled.
-- @param actor [Player]
function Ragdoll:PlayerThink(actor)
  if !actor:Alive() and actor:is_ragdolled() then
    --- GMod's `PlayerDeathThink` hook, run again by the Ragdoll plugin.
    -- Besides the engine's own calls, the plugin runs it on the server from its `PlayerThink`
    -- handler for every dead player who is ragdolled. This call ignores what the handlers
    -- return.
    -- @param actor [Player The dead player]
    hook.Run('PlayerDeathThink', actor)
  end
end

--- Makes sure that a get up timer does what it promised even if its timed action was
-- cancelled or could not start: the action is started again, and the player gets up once
-- the time is up.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function Ragdoll:PlayerOneSecond(actor, cur_time)
  local data = actor.ragdoll_data

  if !data or !data.getup_end or !actor:Alive() then return end

  local action = Flux.TimedAction:get(actor)

  if action and action.id == 'getup' then return end

  local remaining = data.getup_end - cur_time

  if remaining > 0 then
    actor:set_getup_time(remaining)
  else
    data.getup_end = nil

    actor:set_ragdoll_state(RAGDOLL_NONE)
  end
end

--- Keeps the ragdoll of the player in what is networked to them, however far it ends up
-- from where they fell.
-- @param actor [Player]
-- @param view_entity [Entity the entity the player sees through]
function Ragdoll:SetupPlayerVisibility(actor, view_entity)
  local ragdoll = actor:GetDTEntity(ENT_RAGDOLL)

  if IsValid(ragdoll) then
    AddOriginToPVS(ragdoll:GetPos())
  end
end

--- Passes damage dealt to the ragdoll of a living player on to that player. Damage that was
-- not dealt by a player is ignored while the ragdoll is immune, which it is for a moment
-- after the player has fallen; PlayerRagdollCanTakeDamage can block the rest.
-- @param entity [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
function Ragdoll:EntityTakeDamage(entity, damage_info)
  if !entity:IsRagdoll() then return end

  local owner = entity.player

  if !IsValid(owner) or !owner:Alive() then return end

  local data = owner.ragdoll_data

  if data and data.entity == entity and (data.immunity or 0) > CurTime() then
    local attacker = damage_info:GetAttacker()

    if !IsValid(attacker) or !attacker:IsPlayer() then return end
  end

  --- Asks whether damage dealt to the ragdoll of a living player is passed on to them.
  -- Called on the server for every hit the ragdoll takes once its immunity is over, and
  -- during the immunity for hits dealt by players.
  -- @param owner [Player The player lying on the ground]
  -- @param ragdoll [Entity Their ragdoll]
  -- @param damage_info [CTakeDamageInfo The damage]
  -- @return [Boolean Return false to keep the player from taking the damage]
  if hook.Run('PlayerRagdollCanTakeDamage', owner, entity, damage_info) == false then return end

  owner:TakeDamageInfo(damage_info)
end

--- Makes a player fall over when they take at least as much damage from a fall as the
-- ragdoll_fall_damage config, or from anything else as the ragdoll_hit_damage config. A
-- fall leaves them down until they get up by themselves; a hit throws them down for the
-- ragdoll_hit_time config. Both are off while their config is 0.
-- @param entity [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
-- @param took [Boolean whether the entity has actually taken the damage]
function Ragdoll:PostEntityTakeDamage(entity, damage_info, took)
  if !took or !entity:IsPlayer() or !entity:Alive() or entity:InVehicle() or entity:is_ragdolled() then
    return
  end

  local fell = damage_info:IsFallDamage()
  local threshold = Config.get(fell and 'ragdoll_fall_damage' or 'ragdoll_hit_damage', 0)

  if threshold <= 0 or damage_info:GetDamage() < threshold then return end

  local delay = !fell and Config.get('ragdoll_hit_time', 8) or nil
  local force = !fell and damage_info:GetDamageForce() or nil

  timer.Simple(0, function()
    if IsValid(entity) and entity:Alive() and !entity:is_ragdolled() then
      entity:set_ragdoll_state(RAGDOLL_FALLENOVER, delay, { force = force })
    end
  end)
end
