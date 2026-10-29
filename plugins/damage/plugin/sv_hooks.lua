--- Server hooks of the Damage plugin: scale the damage players and NPCs take, run the
-- `ResolvePlayerDamage`, `PrePlayerTakeDamage` and `PostPlayerTakeDamage` hooks around it,
-- and drive the health regeneration, the drowning and the logs.
-- The handlers of GMod's damage hooks change the damage in place and return nothing, so the
-- handlers of the schema, of other plugins and of the gamemode still run after them. The
-- exceptions are damage blocked through `ResolvePlayerDamage` and damage canceled through
-- `PrePlayerTakeDamage`, which are blocked for everyone.

local config_get = Config.get

--- Remembers the location of a bullet or melee hit on a player and multiplies its damage by
-- the 'damage_scale_' config of that location, see `Damage:scale_hit`.
-- @param victim [Player]
-- @param hitgroup [Number HITGROUP_ enum of the hit location]
-- @param damage_info [CTakeDamageInfo]
function Damage:ScalePlayerDamage(victim, hitgroup, damage_info)
  self:set_hitgroup(victim, hitgroup)
  self:scale_hit(victim, hitgroup, damage_info)
end

--- Remembers the location and the unscaled damage of a bullet or melee hit on an NPC and,
-- while the 'damage_scale_npcs' config is on, multiplies its damage by the 'damage_scale_'
-- config of that location, see `Damage:scale_hit`.
-- @param npc [NPC]
-- @param hitgroup [Number HITGROUP_ enum of the hit location]
-- @param damage_info [CTakeDamageInfo]
function Damage:ScaleNPCDamage(npc, hitgroup, damage_info)
  self:set_hitgroup(npc, hitgroup)
  self:add_unscaled_damage(npc, damage_info:GetDamage())
  self:scale_hit(npc, hitgroup, damage_info)
end

--- Works out the hit location multiplier of a damage event on an NPC, see
-- `Damage:measure_npc_damage_scale`. Lets the ResolvePlayerDamage hook work out the amount
-- of any damage to a player, multiplies the fall damage of a player by the
-- 'damage_scale_fall' config, whichever way the amount was worked out (the
-- `GetPlayerFallDamage` hook or the formula of the gamemode), and lets the
-- PrePlayerTakeDamage hook change or cancel any damage to a player.
-- @param entity [Entity the entity taking damage]
-- @param damage_info [CTakeDamageInfo]
-- @return [Boolean true to block damage that one of the hooks has blocked, nil otherwise]
function Damage:EntityTakeDamage(entity, damage_info)
  if !IsValid(entity) then return end

  if !entity:IsPlayer() then
    if entity:IsNPC() then
      self:measure_npc_damage_scale(entity, damage_info)
    end

    return
  end

  local hitgroup = self:get_hitgroup(entity)

  --- Lets a plugin work out the amount of damage a player is about to take from scratch,
  -- such as by rolling dice for it. Called on the server from the Damage plugin's
  -- `EntityTakeDamage` handler for every damage to a player, before the fall damage
  -- multiplier and before `PrePlayerTakeDamage`, so that both of them, and every
  -- `EntityTakeDamage` handler after the plugin, see the amount that was set here. The hit
  -- location multiplier of a bullet or melee hit has already been applied to the damage by
  -- then; a handler that replaces the amount applies `Damage:get_hitgroup_scale(hitgroup)`
  -- to it again.
  -- ```
  -- -- Every hit deals exactly 10 damage before the multipliers.
  -- function MyPlugin:ResolvePlayerDamage(victim, damage_info, hitgroup)
  --   if !damage_info:IsFallDamage() then
  --     damage_info:SetDamage(10 * Damage:get_hitgroup_scale(hitgroup))
  --   end
  -- end
  -- ```
  -- @param victim [Player The player about to take the damage]
  -- @param damage_info [CTakeDamageInfo The damage being dealt, changed in place]
  -- @param hitgroup [Number HITGROUP_ enum of the hit location; HITGROUP_GENERIC when the
  --   damage does not come from a bullet or melee hit]
  -- @return [Boolean Return true to block the damage: nothing is dealt and no further
  --   handler runs. Return nothing to let other handlers run]
  if hook.Run('ResolvePlayerDamage', entity, damage_info, hitgroup) == true then
    entity.damage_hitgroup = nil

    return true
  end

  if damage_info:IsFallDamage() then
    local scale = config_get('damage_scale_fall', 1)

    if scale != 1 then
      damage_info:ScaleDamage(scale)
    end
  end

  --- Called on the server when a player is about to take damage, before it is applied.
  -- Change `damage_info` in place to adjust the damage, or return false to cancel it.
  -- Runs from the Damage plugin's `EntityTakeDamage` handler, after `ResolvePlayerDamage`
  -- and the hit location and fall damage multipliers. The `EntityTakeDamage` handlers of the
  -- schema and of the plugins loaded after this one run later and may still change or block
  -- the damage; use `PostPlayerTakeDamage` for what was dealt in the end.
  -- @param victim [Player The player about to take the damage]
  -- @param damage_info [CTakeDamageInfo The damage being dealt]
  -- @param hitgroup [Number HITGROUP_ enum of the hit location; HITGROUP_GENERIC when the
  --   damage does not come from a bullet or melee hit]
  -- @return [Boolean Return false to cancel the damage: nothing is dealt and no further
  --   handler runs. Return nothing to let other handlers run]
  if hook.Run('PrePlayerTakeDamage', entity, damage_info, hitgroup) == false then
    entity.damage_hitgroup = nil

    return true
  end
end

--- Forgets the hit location of an NPC that has been hit. Handles damage that has been dealt
-- to a player: restarts the wait for their health regeneration, punches their view if the
-- 'damage_view_punch' config is on, writes the damage log entry if the 'log_damage' config is
-- on and runs the PostPlayerTakeDamage hook.
-- @param entity [Entity the entity that was attacked]
-- @param damage_info [CTakeDamageInfo]
-- @param took [Boolean whether the entity has actually taken the damage]
function Damage:PostEntityTakeDamage(entity, damage_info, took)
  if !IsValid(entity) then return end

  if !entity:IsPlayer() then
    entity.damage_hitgroup = nil

    return
  end

  local hitgroup = self:get_hitgroup(entity)

  entity.damage_hitgroup = nil

  local damage = took and damage_info:GetDamage() or 0

  if damage > 0 then
    entity.next_health_regen = nil

    if entity:Alive() and config_get('damage_view_punch') then
      self:punch_view(entity, damage)
    end

    if config_get('log_damage') then
      self:log_damage(entity, damage_info, hitgroup)
    end
  end

  --- Called on the server after damage to a player has been processed by the engine, from
  -- the Damage plugin's `PostEntityTakeDamage` handler. By now every handler has had its say
  -- about the damage and the health of the player is already reduced; a player killed by the
  -- damage is dead. The return value is ignored: return nothing, so that other handlers run.
  -- @param victim [Player The player who was attacked]
  -- @param damage_info [CTakeDamageInfo The damage that was dealt, with the changes every
  --   handler has made to it]
  -- @param took [Boolean Whether the player has actually taken the damage, as the engine
  --   reports it to `PostEntityTakeDamage`]
  -- @param hitgroup [Number HITGROUP_ enum of the hit location; HITGROUP_GENERIC when the
  --   damage does not come from a bullet or melee hit]
  hook.Run('PostPlayerTakeDamage', entity, damage_info, took, hitgroup)
end

--- Clears what the plugin tracks about the player who died, writes the kill log entry if
-- the 'log_kills' config is on and saves the queued log entries, so that the hits that led
-- to the death are in the database together with it.
-- @param victim [Player the player who died]
-- @param inflictor [Entity entity that has dealt the fatal damage]
-- @param attacker [Entity entity responsible for the death]
function Damage:PlayerDeath(victim, inflictor, attacker)
  self:reset_player(victim)

  if config_get('log_kills') then
    self:log_kill(victim, inflictor, attacker)
  end

  self:flush_logs()
end

--- Saves the log entries that were written during the last second.
function Damage:OneSecond()
  self:flush_logs()
end

--- Saves the log entries that are still queued when the server shuts down.
function Damage:ShutDown()
  self:flush_logs()
end

--- Clears what the plugin tracks about the player when they spawn.
-- @param actor [Player]
function Damage:PlayerSpawn(actor)
  self:reset_player(actor)
end

--- Tracks how long the player has been under water and deals the drowning damage while the
-- 'drowning' config is on.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function Damage:PlayerThink(actor, cur_time)
  if config_get('drowning') then
    self:update_drowning(actor, cur_time)
  elseif actor.submerged_since then
    actor.submerged_since = nil
    actor.next_drown_damage = nil
  end
end

--- Regenerates the health of the player while the 'health_regen' config is on.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function Damage:PlayerOneSecond(actor, cur_time)
  if config_get('health_regen') then
    self:regenerate_health(actor, cur_time)
  end
end
