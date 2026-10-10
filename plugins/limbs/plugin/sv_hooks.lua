--- Server-side hooks of the Limbs plugin: they watch the damage that players take and turn
-- it into limb damage, reset the limbs of players who die and let limbs recover over time.
-- None of the damage handlers returns a value or changes the damage, so they work alongside
-- the damage handlers of the schema and of other plugins.
--
-- With the Damage plugin loaded the hit location comes from its `PostPlayerTakeDamage`
-- hook, which already carries it; without it the plugin remembers the location from
-- `ScalePlayerDamage` itself and reads it back in `PostEntityTakeDamage`.

local tick_count = engine.TickCount

--- Remembers the body part that an attack on a player was traced to, for the damage that
-- follows in the same tick. The damage is left as it is. Not needed while the Damage
-- plugin is loaded, which passes the location to `PostPlayerTakeDamage`.
-- @param victim [Player]
-- @param hitgroup [Number HITGROUP_ enum of the body part that was hit]
-- @param damage_info [CTakeDamageInfo]
function Limbs:ScalePlayerDamage(victim, hitgroup, damage_info)
  if Damage then return end

  victim.limb_hitgroup = hitgroup
  victim.limb_hit_tick = tick_count()
end

--- Remembers the health of a player who is about to take damage, so that the health they
-- actually lose is known once the damage has been dealt. The damage is left as it is.
-- @param entity [Entity the entity that is about to take damage]
-- @param damage_info [CTakeDamageInfo]
function Limbs:EntityTakeDamage(entity, damage_info)
  if IsValid(entity) and entity:IsPlayer() then
    entity.limb_health_before = entity:Health()
    entity.limb_health_tick = tick_count()
  end
end

--- Hurts the limbs of a player who has taken damage, from the `PostPlayerTakeDamage` hook
-- of the Damage plugin, which carries the hit location.
-- @param victim [Player the player who has taken damage]
-- @param damage_info [CTakeDamageInfo]
-- @param took [Boolean whether the damage was actually dealt]
-- @param hitgroup [Number HITGROUP_ enum of the hit location]
function Limbs:PostPlayerTakeDamage(victim, damage_info, took, hitgroup)
  self:handle_damage(victim, damage_info, took, hitgroup)
end

--- Hurts the limbs of a player who has taken damage, with the hit location that
-- `ScalePlayerDamage` has remembered. Only used without the Damage plugin.
-- @param victim [Entity the entity that has taken damage]
-- @param damage_info [CTakeDamageInfo]
-- @param took [Boolean whether the damage was actually dealt]
function Limbs:PostEntityTakeDamage(victim, damage_info, took)
  if Damage or !IsValid(victim) or !victim:IsPlayer() then return end

  local hitgroup

  if victim.limb_hit_tick == tick_count() then
    hitgroup = victim.limb_hitgroup
  end

  victim.limb_hit_tick = nil

  self:handle_damage(victim, damage_info, took, hitgroup)
end

--- Hurts the limbs of a player who has taken damage. This runs after the damage has been
-- dealt, so damage that was blocked hurts nothing and damage that other handlers have scaled
-- counts as it was dealt. Limb damage is worked out from the health the player has lost,
-- which leaves out what their armor has absorbed, times the 'limbs_damage_scale' config.
-- @param victim [Player the player who has taken damage]
-- @param damage_info [CTakeDamageInfo]
-- @param took [Boolean whether the damage was actually dealt]
-- @param hitgroup=nil [Number HITGROUP_ enum of the hit location; nil or HITGROUP_GENERIC
--   for damage without one]
function Limbs:handle_damage(victim, damage_info, took, hitgroup)
  if !IsValid(victim) or !victim:IsPlayer() then return end

  local health_before

  if victim.limb_health_tick == tick_count() then
    health_before = victim.limb_health_before
  end

  victim.limb_health_tick = nil

  if !took or !victim:Alive() or !self:is_enabled() then return end

  local amount = damage_info:GetDamage()

  if health_before then
    amount = math.min(amount, health_before - victim:Health())
  end

  if amount <= 0 then return end

  local hits = self:get_hits(victim, damage_info, amount, hitgroup)

  --- Lets plugins change which limbs of a player are hurt by damage they have taken. Called
  -- on the server after the damage has been dealt to a player who survived it, while limb
  -- damage is enabled, also when the damage has no location and the table is empty. Every
  -- handler may change the table, so a handler should return nothing to let the others run.
  -- ```
  -- -- Explosions hurt every limb a little.
  -- function MyPlugin:AdjustLimbHits(victim, damage_info, hits, amount)
  --   if damage_info:IsExplosionDamage() then
  --     for k, v in ipairs(Limbs:all()) do
  --       hits[v] = (hits[v] or 0) + amount * 0.25
  --     end
  --   end
  -- end
  -- ```
  -- @param victim [Player The player who has taken the damage]
  -- @param damage_info [CTakeDamageInfo The damage that was dealt; changing it has no effect]
  -- @param hits [Map Limb damage to add by limb ID, modified in place: the hit limb for a
  --   traced hit, both legs for fall damage, empty for damage without a location]
  -- @param amount [Number Health that the player has lost to the damage]
  hook.Run('AdjustLimbHits', victim, damage_info, hits, amount)

  self:damage_limbs(victim, hits)
end

--- Resets the limbs of a player who dies, before their character is saved.
-- @param victim [Player]
-- @param attacker [Entity]
-- @param damage_info [CTakeDamageInfo]
function Limbs:DoPlayerDeath(victim, attacker, damage_info)
  self:reset(victim)
end

--- Lets the hurt limbs of a living player recover by the 'limbs_recovery' config once a
-- minute.
-- @param actor [Player]
function Limbs:PlayerOneMinute(actor)
  if !self:is_enabled() or !actor:Alive() or !self:get_stored(actor) then return end

  local amount = Config.get('limbs_recovery', 5)

  --- Lets plugins change how much the limbs of a player recover on their own. Called on the
  -- server once a minute for every living player who has a hurt limb, while limb damage is
  -- enabled.
  -- @param actor [Player The player whose limbs are about to recover]
  -- @param amount [Number Damage that is about to be taken off each hurt limb, from the
  --   'limbs_recovery' config]
  -- @return [Number Amount to take off instead, 0 for no recovery; nothing to keep it]
  local override = hook.Run('GetLimbRecovery', actor, amount)

  if isnumber(override) then
    amount = override
  end

  if amount > 0 then
    self:heal_all(actor, amount)
  end
end
