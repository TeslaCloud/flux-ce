--- Server hooks of the D20 plugin: roll the damage of hits on players (through the
-- `ResolvePlayerDamage` hook of the Damage plugin) and on NPCs, roll fall damage, scale the
-- health of NPCs that spawn and check the dice formulas of the configs.
-- The damage handlers change the damage in place and return nothing, except that they block
-- the extra damage events of an attack that has already been rolled in the same tick.

--- Rolls the damage of a hit on a player, before the fall damage multiplier and the
-- `PrePlayerTakeDamage` hook of the Damage plugin see it, and applies the 'damage_scale_'
-- config of the hit location to the rolled total again, as the Damage plugin has applied it
-- to the damage of the engine in `ScalePlayerDamage` already.
-- @param victim [Player the player about to take the damage]
-- @param damage_info [CTakeDamageInfo the damage, changed in place]
-- @param hitgroup [Number HITGROUP_ enum of the hit location]
-- @return [Boolean true to block an extra damage event of an attack that has already been
--   rolled, nil otherwise]
function D20:ResolvePlayerDamage(victim, damage_info, hitgroup)
  return self:roll_damage(victim, damage_info, Damage:get_hitgroup_scale(hitgroup))
end

--- Rolls the damage of a hit on an NPC and applies the hit location multiplier of the
-- `ScaleNPCDamage` handlers, `Damage:get_npc_damage_scale`, to the rolled total. Hits on
-- players are rolled through the `ResolvePlayerDamage` hook of the Damage plugin instead.
-- @param entity [Entity the entity about to take the damage]
-- @param damage_info [CTakeDamageInfo the damage, changed in place]
-- @return [Boolean true to block an extra damage event of an attack that has already been
--   rolled, nil otherwise]
function D20:EntityTakeDamage(entity, damage_info)
  if !IsValid(entity) or !entity:IsNPC() then return end

  return self:roll_damage(entity, damage_info, Damage:get_npc_damage_scale(entity, damage_info))
end

--- Rolls the fall damage of a player, see `D20:roll_fall_damage`.
-- @param actor [Player the player who has hit the ground]
-- @param speed [Number fall speed]
-- @return [Number damage to deal, nil while the plugin is disabled]
function D20:GetPlayerFallDamage(actor, speed)
  return self:roll_fall_damage(actor, speed)
end

--- Scales the health of an NPC that has spawned, on the next tick, once the NPC has its
-- health set.
-- @param entity [Entity the entity that was created]
function D20:OnEntityCreated(entity)
  if !entity:IsNPC() then return end

  timer.Simple(0, function()
    if IsValid(entity) then
      D20:scale_npc_health(entity)
    end
  end)
end

--- Checks the dice formulas of the configs of the plugin when they are set.
-- @param key [String config key]
-- @param _old_value [Any]
-- @param new_value [Any]
function D20:ConfigChanged(key, _old_value, new_value)
  self:check_config(key, new_value)
end
