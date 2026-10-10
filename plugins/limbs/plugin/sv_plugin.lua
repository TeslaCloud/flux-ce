--- Server-side functions of the Limbs plugin: hurting, healing and resetting the limbs of a
-- player, and working out which limbs a hit has landed on.

local tonumber = tonumber
local math_clamp = math.Clamp

--- Applies changes to the limb damage of a player's active character in one go: the new
-- damage of every limb is kept between 0 and `Limbs.max_damage`, the character data is
-- written once, which also sends it to the player, and the PlayerLimbDamaged and
-- PlayerLimbHealed hooks are run for every limb that has changed.
-- @param target [Player]
-- @param changes [Map amount by limb ID: positive amounts hurt, negative amounts heal; both
--   are rounded up to whole points, unknown limbs are skipped]
-- @return [Map the change that was applied by limb ID, limbs that did not change left out]
local function change_limbs(target, changes)
  local applied = {}

  if !IsValid(target) or !target:IsPlayer() or !target:is_character_loaded() then
    return applied
  end

  local stored = Limbs:get_stored(target) or {}
  local max_damage = Limbs.max_damage

  for limb, amount in pairs(changes) do
    amount = tonumber(amount)

    if Limbs:is_limb(limb) and amount and amount == amount and amount != 0 then
      local current = math_clamp(tonumber(stored[limb]) or 0, 0, max_damage)
      local rounded = amount > 0 and math.ceil(amount) or -math.ceil(-amount)
      local new_damage = math_clamp(current + rounded, 0, max_damage)

      if new_damage != current then
        stored[limb] = new_damage > 0 and new_damage or nil
        applied[limb] = new_damage - current
      end
    end
  end

  if next(applied) == nil then
    return applied
  end

  target:set_character_data(Limbs.data_key, next(stored) != nil and stored or nil)

  for limb, amount in pairs(applied) do
    local new_damage = tonumber(stored[limb]) or 0

    if amount > 0 then
      --- Called on the server after a limb of a player has been hurt, whether by damage the
      -- player took or through `Limbs:damage`, `Limbs:damage_limbs` or `Limbs:set_damage`.
      -- Not called for a hit on a limb that is already crippled.
      -- @param target [Player The player whose limb was hurt]
      -- @param limb [String Limb ID]
      -- @param amount [Number Damage that was added to the limb, in whole points]
      -- @param damage [Number Damage of the limb now, up to 100]
      hook.Run('PlayerLimbDamaged', target, limb, amount, new_damage)
    else
      --- Called on the server after a limb of a player has been healed, whether by natural
      -- recovery or through `Limbs:heal`, `Limbs:heal_all` or `Limbs:set_damage`. Not called
      -- when all limbs are cleared at once, which runs PlayerLimbsReset instead.
      -- @param target [Player The player whose limb was healed]
      -- @param limb [String Limb ID]
      -- @param amount [Number Damage that was taken off the limb, in whole points]
      -- @param damage [Number Damage of the limb now, 0 once it is healthy]
      hook.Run('PlayerLimbHealed', target, limb, -amount, new_damage)
    end
  end

  return applied
end

--- Hurts one limb of a player. The damage is added to what the limb already has, up to
-- 100, saved with the active character of the player and sent to them. Nothing happens
-- while limb damage is disabled, or when the player has no active character.
-- ```
-- -- A bear trap.
-- Limbs:damage(activator, 'left_leg', 60)
-- ```
-- @param target [Player]
-- @param limb [String limb ID]
-- @param amount [Number damage to add, rounded up to a whole point]
-- @return [Number the damage that was added, 0 if the limb did not change]
function Limbs:damage(target, limb, amount)
  amount = tonumber(amount)

  if !self:is_enabled() or !self:is_limb(limb) or !amount or amount <= 0 then
    return 0
  end

  return change_limbs(target, { [limb] = amount })[limb] or 0
end

--- Hurts several limbs of a player at once, which saves and sends the limbs only once.
-- Nothing happens while limb damage is disabled.
-- ```
-- Limbs:damage_limbs(target, { left_leg = 20, right_leg = 20 })
-- ```
-- @param target [Player]
-- @param hits [Map damage to add by limb ID; amounts that are not positive are skipped]
-- @return [Map the damage that was added by limb ID, limbs that did not change left out]
function Limbs:damage_limbs(target, hits)
  local changes = {}

  if self:is_enabled() and istable(hits) then
    for limb, amount in pairs(hits) do
      amount = tonumber(amount)

      if amount and amount > 0 then
        changes[limb] = amount
      end
    end
  end

  return change_limbs(target, changes)
end

--- Heals one limb of a player. Works whether limb damage is enabled or not.
-- ```
-- -- A splint takes half of the damage off a leg.
-- Limbs:heal(actor, 'right_leg', 50)
-- ```
-- @param target [Player]
-- @param limb [String limb ID]
-- @param amount=100 [Number damage to take off, rounded up to a whole point; heals the limb
--   completely when omitted]
-- @return [Number the damage that was taken off, 0 if the limb did not change]
function Limbs:heal(target, limb, amount)
  amount = amount == nil and self.max_damage or tonumber(amount)

  if !self:is_limb(limb) or !amount or amount <= 0 then
    return 0
  end

  local healed = change_limbs(target, { [limb] = -amount })[limb]

  return healed and -healed or 0
end

--- Heals every hurt limb of a player by the same amount. Works whether limb damage is
-- enabled or not. This is what medical items should call: healing the health of a player
-- does not heal their limbs.
-- ```
-- Limbs:heal_all(actor, 25)
-- ```
-- @param target [Player]
-- @param amount=100 [Number damage to take off each limb, rounded up to a whole point;
--   heals the limbs completely when omitted]
-- @return [Number the damage that was taken off all limbs together]
function Limbs:heal_all(target, amount)
  amount = amount == nil and self.max_damage or tonumber(amount)

  if !amount or amount <= 0 then
    return 0
  end

  local changes = {}

  for k, v in ipairs(self:all()) do
    changes[v] = -amount
  end

  local total = 0

  for limb, healed in pairs(change_limbs(target, changes)) do
    total = total - healed
  end

  return total
end

--- Sets the damage of one limb of a player to a value, hurting or healing it as needed.
-- Raising the damage does nothing while limb damage is disabled.
-- @param target [Player]
-- @param limb [String limb ID]
-- @param value [Number new damage, kept between 0 and 100]
-- @return [Number the change that was applied: positive if the limb was hurt, negative if it
--   was healed, 0 if it did not change]
function Limbs:set_damage(target, limb, value)
  value = tonumber(value)

  if !value or !self:is_limb(limb) then
    return 0
  end

  local stored = self:get_stored(target)
  local current = math_clamp(stored and tonumber(stored[limb]) or 0, 0, self.max_damage)
  local difference = math_clamp(value, 0, self.max_damage) - current

  if difference > 0 then
    return self:damage(target, limb, difference)
  elseif difference < 0 then
    local healed = self:heal(target, limb, -difference)

    return healed > 0 and -healed or 0
  end

  return 0
end

--- Clears the damage of all limbs of a player at once. The plugin does this when a player
-- dies. Works whether limb damage is enabled or not.
-- @param target [Player]
-- @return [Boolean true if any limb was hurt and has been cleared, false otherwise]
function Limbs:reset(target)
  local stored = self:get_stored(target)

  if !stored or next(stored) == nil then
    return false
  end

  target:set_character_data(self.data_key, nil)

  --- Called on the server after all limbs of a player have been cleared at once: when the
  -- player dies or when `Limbs:reset` is called. Not called if no limb was hurt.
  -- @param target [Player The player whose limbs were reset]
  hook.Run('PlayerLimbsReset', target)

  return true
end

--- Finds the limb of a fallen player that is closest to a position, by looking for the
-- nearest physics bone of their ragdoll. Needs the Ragdoll plugin.
-- @param target [Player]
-- @param position [Vector world position, e.g. where the damage was dealt]
-- @return [String limb ID, or nil if the player has no ragdoll, the position is not set or
--   the nearest bone is not a known part of a limb]
function Limbs:find_ragdoll_limb(target, position)
  if !isfunction(target.get_ragdoll_entity) then return end
  if !isvector(position) or position:IsZero() then return end

  local ragdoll = target:get_ragdoll_entity()

  if !IsValid(ragdoll) then return end

  local closest, closest_distance

  for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
    local phys_obj = ragdoll:GetPhysicsObjectNum(i)

    if IsValid(phys_obj) then
      local distance = phys_obj:GetPos():DistToSqr(position)

      if !closest_distance or distance < closest_distance then
        closest = i
        closest_distance = distance
      end
    end
  end

  if !closest then return end

  local bone = ragdoll:TranslatePhysBoneToBone(closest)

  if !bone or bone < 0 then return end

  return self:from_bone(ragdoll:GetBoneName(bone))
end

--- Works out which limbs a hit has landed on and how much damage each of them takes, before
-- the AdjustLimbHits hook has its say. Fall damage is split between the legs when the
-- 'limbs_fall_damage' config is on; other damage goes to the limb of the hit group, or, for
-- a fallen player, to the limb of their ragdoll that is closest to the hit.
-- @param victim [Player]
-- @param damage_info [CTakeDamageInfo the damage that was dealt]
-- @param amount [Number health that the player has lost]
-- @param hitgroup=nil [Number HITGROUP_ enum of the body part the hit was traced to, nil if
--   it was not traced]
-- @return [Map limb damage by limb ID; empty if the hit has no location]
function Limbs:get_hits(victim, damage_info, amount, hitgroup)
  local hits = {}
  local limb_damage = amount * Config.get('limbs_damage_scale', 2)

  if limb_damage <= 0 then
    return hits
  end

  if damage_info:IsFallDamage() then
    if Config.get('limbs_fall_damage', true) then
      hits.left_leg = limb_damage * 0.5
      hits.right_leg = limb_damage * 0.5
    end

    return hits
  end

  local limb = hitgroup and self:from_hitgroup(hitgroup)

  if !limb then
    limb = self:find_ragdoll_limb(victim, damage_info:GetDamagePosition())
  end

  if limb then
    hits[limb] = limb_damage
  end

  return hits
end
