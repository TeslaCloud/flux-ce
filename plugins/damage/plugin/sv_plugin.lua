--- Server side of the Damage plugin: the rules it applies to players.
-- Looks up the multiplier of a hit location, remembers where a player has just been hit,
-- regenerates health, hurts players who stay under water with damage rolled from the
-- 'drowning_damage' dice formula, punches the view of a player who is hurt and writes the
-- damage and kill log entries. The hooks that call these functions are in `sv_hooks.lua`.
--
-- The log entries are printed and replicated the moment they are written, but they are
-- saved to the database in one go by `Damage:flush_logs`, which runs once a second and
-- when a player dies, so that a hit does not cost a database insert of its own.

local IsValid = IsValid
local CurTime = CurTime
local config_get = Config.get
local isstring = isstring
local tonumber = tonumber
local math_max = math.max
local rand = math.Rand

--- Config key of the damage multiplier of each hit location that has one.
local hitgroup_scales = {
  [HITGROUP_HEAD] = 'damage_scale_head',
  [HITGROUP_CHEST] = 'damage_scale_chest',
  [HITGROUP_STOMACH] = 'damage_scale_stomach',
  [HITGROUP_LEFTARM] = 'damage_scale_arms',
  [HITGROUP_RIGHTARM] = 'damage_scale_arms',
  [HITGROUP_LEFTLEG] = 'damage_scale_legs',
  [HITGROUP_RIGHTLEG] = 'damage_scale_legs'
}

--- Console color of the damage log entries.
local damage_log_color = Color(255, 170, 60)

--- Console color of the kill log entries.
local kill_log_color = Color(255, 80, 80)

--- Largest angle, in degrees, that a single hit can punch the view of a player by.
local max_view_punch = 30

--- Log entries that are waiting to be saved to the database, in the order they were
-- written, each with the body, action, object and subject of a Log record.
local pending_logs = {}

--- The players who receive the replicated log entries, and the CurTime() until which the
-- list is trusted.
local log_viewers = {}
local log_viewers_until = 0

--- Returns what a log entry stores as its object or subject for an entity.
-- @param entity [Entity]
-- @return [Number/String ID of the database record of a player, or their SteamID if they
--   have no record; the class of any other entity; nil for the world and invalid entities]
local function get_log_id(entity)
  if !IsValid(entity) then return end

  if entity:IsPlayer() then
    return entity.record and entity.record.id or entity:SteamID()
  end

  return entity:GetClass()
end

--- Returns the damage multiplier set in the config for a hit location. Serverside only.
-- @param hitgroup [Number HITGROUP_ enum]
-- @return [Number multiplier: the 'damage_scale_' config of the location, or 1 for
--   HITGROUP_GENERIC, HITGROUP_GEAR and anything else that has no config]
function Damage:get_hitgroup_scale(hitgroup)
  local key = hitgroup_scales[hitgroup]

  if !key then
    return 1
  end

  return config_get(key, 1)
end

--- Remembers the location of the hit a player or an NPC is about to take damage from. The
-- engine only reports it to `ScalePlayerDamage` and `ScaleNPCDamage`, so it is kept for the
-- `EntityTakeDamage` and `PostEntityTakeDamage` handlers that follow in the same tick.
-- Serverside only.
-- @param victim [Entity player or NPC]
-- @param hitgroup [Number HITGROUP_ enum]
function Damage:set_hitgroup(victim, hitgroup)
  victim.damage_hitgroup = hitgroup
  victim.damage_hitgroup_time = CurTime()
end

--- Returns the location of the hit behind the damage that a player or an NPC is taking.
-- Only meaningful while that damage is being processed, that is inside of
-- `EntityTakeDamage` handlers and, for players, `PrePlayerTakeDamage` and
-- `PostPlayerTakeDamage` handlers. Serverside only.
-- @param victim [Entity player or NPC]
-- @return [Number HITGROUP_ enum; HITGROUP_GENERIC when the damage does not come from a
--   bullet or melee hit, e.g. a fall, an explosion or drowning]
function Damage:get_hitgroup(victim)
  if victim.damage_hitgroup and victim.damage_hitgroup_time == CurTime() then
    return victim.damage_hitgroup
  end

  return HITGROUP_GENERIC
end

--- Multiplies the damage of a bullet or melee hit by the 'damage_scale_' config of its
-- location, for an NPC only while the 'damage_scale_npcs' config is on, and runs the
-- `AdjustEntityDamageScale` hook. What the handlers of the hook have multiplied the damage by
-- is kept for `Damage:get_player_damage_scale`. Serverside only.
-- @param victim [Entity player or NPC that was hit]
-- @param hitgroup [Number HITGROUP_ enum of the hit location]
-- @param damage_info [CTakeDamageInfo the damage, changed in place]
function Damage:scale_hit(victim, hitgroup, damage_info)
  if victim:IsPlayer() or config_get('damage_scale_npcs') then
    local scale = self:get_hitgroup_scale(hitgroup)

    if scale != 1 then
      damage_info:ScaleDamage(scale)
    end
  end

  --- Lets plugins and the schema multiply the damage of a bullet or melee hit on a player
  -- or an NPC by its location. Called on the server from the Damage plugin's
  -- `ScalePlayerDamage` and `ScaleNPCDamage` handlers, after the 'damage_scale_' configs
  -- have been applied. Scale the damage in place. The multiplier also applies to damage
  -- that is rolled anew through `ResolvePlayerDamage`, such as by the D20 plugin.
  -- ```
  -- -- Helmets halve hits to the head.
  -- function MyPlugin:AdjustEntityDamageScale(victim, hitgroup, damage_info)
  --   if hitgroup == HITGROUP_HEAD and victim:IsPlayer() and victim:has_item_equipped('helmet') then
  --     damage_info:ScaleDamage(0.5)
  --   end
  -- end
  -- ```
  -- @param victim [Entity The player or NPC that was hit]
  -- @param hitgroup [Number HITGROUP_ enum of the hit location]
  -- @param damage_info [CTakeDamageInfo The damage being dealt, changed in place]
  -- @return [Any The return value is ignored; a handler that returns a value keeps the
  --   handlers of the hook after it from being called, so return nothing]
  local before = damage_info:GetDamage()

  hook.Run('AdjustEntityDamageScale', victim, hitgroup, damage_info)

  local after = damage_info:GetDamage()

  victim.damage_hit_adjust = before > 0 ? after / before : 1
end

--- Returns the hit location multiplier of the damage that a player is taking: the
-- 'damage_scale_' config of the location of the hit times what the
-- `AdjustEntityDamageScale` handlers have multiplied it by. A `ResolvePlayerDamage` handler
-- that replaces the amount of the damage applies it to the new amount. Only meaningful while
-- that damage is being processed. Serverside only.
-- @param victim [Player]
-- @return [Number multiplier; 1 for damage that was not a bullet or melee hit]
function Damage:get_player_damage_scale(victim)
  if !victim.damage_hitgroup or victim.damage_hitgroup_time != CurTime() then
    return 1
  end

  return self:get_hitgroup_scale(victim.damage_hitgroup) * (victim.damage_hit_adjust or 1)
end

--- Adds the damage of a bullet or melee hit on an NPC, before any hit location multiplier,
-- to what the NPC takes in this tick: the pellets of a shotgun are separate hits that the
-- engine deals as one damage event. Serverside only.
-- @param npc [NPC]
-- @param amount [Number damage of the hit before the multipliers]
function Damage:add_unscaled_damage(npc, amount)
  local cur_time = CurTime()

  if npc.damage_unscaled and npc.damage_unscaled_time == cur_time then
    npc.damage_unscaled += amount
  else
    npc.damage_unscaled = amount
    npc.damage_unscaled_time = cur_time
  end
end

--- Works out the hit location multiplier of the damage event an NPC is taking from the
-- damage that `Damage:add_unscaled_damage` has added up for it, keeps it for
-- `Damage:get_npc_damage_scale` and forgets the added up damage, so that the next event in
-- the same tick starts from nothing. Runs from the plugin's `EntityTakeDamage` handler, before
-- the handlers of the plugins loaded after it, for every event, blocked ones included.
-- Serverside only.
-- @param npc [NPC]
-- @param damage_info [CTakeDamageInfo the damage after the multipliers]
function Damage:measure_npc_damage_scale(npc, damage_info)
  local cur_time = CurTime()
  local unscaled = npc.damage_unscaled_time == cur_time and npc.damage_unscaled
  local scale = 1

  if unscaled and unscaled > 0 then
    scale = damage_info:GetDamage() / unscaled
  end

  npc.damage_unscaled = nil
  npc.damage_unscaled_time = nil
  npc.damage_scale = scale
  npc.damage_scale_time = cur_time
end

--- Returns the hit location multiplier of the damage event that an NPC is taking: every
-- multiplier that the `ScaleNPCDamage` handlers of the plugin, of the plugins loaded after
-- it, of the schema and of the gamemode have applied to the hits of the event. Only
-- meaningful inside of `EntityTakeDamage` handlers that run after the plugin's. Serverside
-- only.
-- @param npc [NPC]
-- @return [Number multiplier; 1 for damage that was not a bullet or melee hit]
function Damage:get_npc_damage_scale(npc)
  if npc.damage_scale_time == CurTime() then
    return npc.damage_scale
  end

  return 1
end

--- Forgets what the plugin tracks about a player over time: the time of their next health
-- regeneration and the time they have spent under water. Serverside only.
-- @param target [Player]
function Damage:reset_player(target)
  target.next_health_regen = nil
  target.submerged_since = nil
  target.next_drown_damage = nil
end

--- Returns how long a player waits for their next bit of regenerated health: the
-- 'health_regen_fast_interval' config when their health is at or above the
-- 'health_regen_fast_share' percentage of their maximum health, the 'health_regen_interval'
-- config otherwise. Serverside only.
-- @param target [Player]
-- @return [Number seconds]
function Damage:get_regen_interval(target)
  local share = target:Health() / math_max(target:GetMaxHealth(), 1) * 100

  if share >= config_get('health_regen_fast_share', 50) then
    return config_get('health_regen_fast_interval', 5)
  end

  return config_get('health_regen_interval', 10)
end

--- Runs the health regeneration of a player: heals them by the 'health_regen_amount' config
-- once their waiting time has passed, never above their maximum health. The waiting time
-- starts when the player is first found hurt and starts over whenever they take damage.
-- Dead players and players at full health do not regenerate. Does not check the
-- 'health_regen' config. Serverside only.
-- @param target [Player]
-- @param cur_time=CurTime() [Number current time]
-- @return [Boolean whether the player was healed by this call]
function Damage:regenerate_health(target, cur_time)
  cur_time = cur_time or CurTime()

  local health, max_health = target:Health(), target:GetMaxHealth()

  if !target:Alive() or health <= 0 or health >= max_health then
    target.next_health_regen = nil

    return false
  end

  if !target.next_health_regen then
    target.next_health_regen = cur_time + self:get_regen_interval(target)

    return false
  end

  if target.next_health_regen > cur_time then
    return false
  end

  target.next_health_regen = cur_time + self:get_regen_interval(target)

  --- Asks whether a player may regenerate health right now. Called on the server each time
  -- a hurt, living player is due to be healed by the health regeneration, which only runs
  -- while the 'health_regen' config is on.
  -- @param target [Player The player about to be healed]
  -- @return [Boolean Return false to skip this heal; the player waits a full interval for
  --   the next one. Return nothing to let other handlers decide]
  if hook.Run('PlayerCanRegenerateHealth', target) == false then
    return false
  end

  local amount = config_get('health_regen_amount', 1)

  --- Lets plugins change how much health a player regenerates at once. Called on the
  -- server right before the player is healed, after `PlayerCanRegenerateHealth`.
  -- @param target [Player The player about to be healed]
  -- @param amount [Number Health the player would gain: the 'health_regen_amount' config]
  -- @return [Number Health to give instead, rounded to a whole number; 0 or less gives
  --   none. Return nothing to keep the amount and let other handlers run]
  local override = hook.Run('GetHealthRegeneration', target, amount)

  if isnumber(override) then
    amount = override
  end

  amount = math.Round(amount)

  if amount <= 0 then
    return false
  end

  target:SetHealth(math.min(health + amount, max_health))

  return true
end

--- Returns how deep a player is in water. For a ragdolled player this is the water level of
-- their ragdoll, which is where their body is. Serverside only.
-- @param target [Player]
-- @return [Number 0 when not in water, 1 slightly submerged, 2 mostly submerged, 3 completely
--   submerged]
function Damage:get_water_level(target)
  if isfunction(target.is_ragdolled) and target:is_ragdolled() then
    local ragdoll = target:get_ragdoll_entity()

    if IsValid(ragdoll) then
      return ragdoll:WaterLevel()
    end
  end

  return target:WaterLevel()
end

--- Returns how long a player has been completely under water without surfacing. It is only
-- tracked while the 'drowning' config is on. Serverside only.
-- @param target [Player]
-- @return [Number seconds; 0 if the player is not submerged]
function Damage:get_submerged_time(target)
  if !target.submerged_since then
    return 0
  end

  return math_max(CurTime() - target.submerged_since, 0)
end

--- Works out the amount of drowning damage from a number or a dice formula. A formula is
-- rolled with `Dice.roll`; one that cannot be rolled, or a value that is neither, comes out
-- as 1. Serverside only.
-- ```
-- Damage:get_drowning_amount('1d4')
-- -- 3
-- ```
-- @param amount [Number/String damage, or a dice formula such as '1d4']
-- @return [Number damage, never below 0]
function Damage:get_drowning_amount(amount)
  if isstring(amount) then
    local number = tonumber(amount)

    if number then
      amount = number
    elseif Dice then
      local result, err = Dice.roll(amount)

      if result then
        amount = result.total
      else
        Flux.dev_print('Invalid drowning damage formula \''..amount..'\': '..tostring(err))
      end
    end
  end

  if !isnumber(amount) or amount != amount then
    return 1
  end

  return math_max(amount, 0)
end

--- Deals drowning damage to a player. The damage is of the DMG_DROWN type with the world as
-- its attacker, ignores armor, and goes through the usual damage hooks. A dice formula is
-- rolled once for this bit of damage, see `Damage:get_drowning_amount`. Serverside only.
-- ```
-- Damage:deal_drowning_damage(target, '2d4')
-- ```
-- @param target [Player]
-- @param amount [Number/String damage to deal, or a dice formula to roll it from; 1 when the
--   formula cannot be rolled]
function Damage:deal_drowning_damage(target, amount)
  local world = game.GetWorld()
  local damage_info = DamageInfo()

  damage_info:SetDamage(self:get_drowning_amount(amount))
  damage_info:SetDamageType(DMG_DROWN)
  damage_info:SetAttacker(world)
  damage_info:SetInflictor(world)

  target:TakeDamageInfo(damage_info)
end

--- Runs the drowning of a player: keeps track of how long they have been completely under
-- water and, once that exceeds the 'drowning_time' config, deals damage rolled from the
-- 'drowning_damage' dice formula to them every 'drowning_interval' seconds until they
-- surface. Dead and noclipping players are left alone. Does not check the 'drowning'
-- config. Serverside only.
-- @param target [Player]
-- @param cur_time=CurTime() [Number current time]
function Damage:update_drowning(target, cur_time)
  cur_time = cur_time or CurTime()

  if !target:Alive() or target:GetMoveType() == MOVETYPE_NOCLIP or self:get_water_level(target) < 3 then
    target.submerged_since = nil
    target.next_drown_damage = nil

    return
  end

  target.submerged_since = target.submerged_since or cur_time

  if cur_time - target.submerged_since < config_get('drowning_time', 20) then return end
  if target.next_drown_damage and target.next_drown_damage > cur_time then return end

  target.next_drown_damage = cur_time + config_get('drowning_interval', 1)

  --- Asks whether a player who has run out of breath takes drowning damage. Called on the
  -- server each time the damage is due, that is every 'drowning_interval' seconds while the
  -- player has been completely under water for longer than the 'drowning_time' config.
  -- Only runs while the 'drowning' config is on.
  -- @param target [Player The player who is drowning]
  -- @return [Boolean Return false to spare the player this time, e.g. for a breathing
  --   apparatus. Return nothing to let other handlers decide]
  if hook.Run('PlayerCanDrown', target) == false then return end

  self:deal_drowning_damage(target, config_get('drowning_damage', '1d4'))
end

--- Punches the view of a player by a random angle that grows with the damage: the damage
-- times the 'damage_view_punch_scale' config in degrees at most, and never more than 30
-- degrees. Serverside only.
-- @param target [Player]
-- @param damage [Number damage the player has taken]
function Damage:punch_view(target, damage)
  local amount = math.min(damage * config_get('damage_view_punch_scale', 1), max_view_punch)

  if amount <= 0 then return end

  target:ViewPunch(Angle(
    rand(-amount, amount),
    rand(-amount, amount),
    rand(-amount, amount) * 0.5
  ))
end

--- Returns the name an entity is given in the damage and kill logs. Serverside only.
-- @param entity [Entity]
-- @return [String name of a player, followed by their Steam name in brackets if it differs;
--   'the world' for the world; the class of any other entity; 'an unknown source' if the
--   entity is not valid]
function Damage:get_log_name(entity)
  if entity == game.GetWorld() then
    return 'the world'
  end

  if !IsValid(entity) then
    return 'an unknown source'
  end

  if entity:IsPlayer() then
    local name, steam_name = entity:name(), entity:steam_name()

    if name != steam_name then
      return name..' ('..steam_name..')'
    end

    return name
  end

  return entity:GetClass()
end

--- Returns the class of what an attacker has dealt damage with: the inflictor if it is an
-- entity of its own (a prop, a grenade), otherwise the weapon a player or an NPC is holding.
-- The held weapon is not named for damage the victim has dealt to themselves.
-- Serverside only.
-- @param attacker [Entity entity responsible for the damage]
-- @param inflictor [Entity entity that has dealt the damage]
-- @param victim=nil [Entity entity that has taken the damage]
-- @return [String entity class, or nil if there is nothing to name]
function Damage:get_weapon_class(attacker, inflictor, victim)
  if IsValid(inflictor) and inflictor != attacker then
    return inflictor:GetClass()
  end

  if IsValid(attacker) and attacker != victim and (attacker:IsPlayer() or attacker:IsNPC()) then
    local weapon = attacker:GetActiveWeapon()

    if IsValid(weapon) then
      return weapon:GetClass()
    end
  end
end

--- Returns the players who receive the replicated damage and kill log entries: those with
-- the 'view_damage_logs' permission. The list is worked out at most once a second, not on
-- every hit. Serverside only.
-- @return [List<Player> do not modify the list]
function Damage:get_log_viewers()
  local cur_time = CurTime()

  if log_viewers_until > cur_time then
    return log_viewers
  end

  log_viewers = {}
  log_viewers_until = cur_time + 1

  local count = 0

  for _, client in player.Iterator() do
    if client:can('view_damage_logs') then
      count += 1
      log_viewers[count] = client
    end
  end

  return log_viewers
end

--- Writes a log entry the way `Log:colored` followed by `Log:replicate` would, except that
-- the entry is not saved right away: it is printed to the server console in its color, sent
-- to the players who view the damage logs, and queued for `Damage:flush_logs`.
-- Serverside only.
-- @param color [Color console color of the entry]
-- @param message [String text of the entry]
-- @param action [String type of the logged event, in snake_case]
-- @param object=nil [String/Number who or what performed the action]
-- @param subject=nil [String/Number who or what the action was performed on]
function Damage:write_log(color, message, action, object, subject)
  MsgC(color, action:camel_case()..' - '..message..'\n')

  Cable.send(
    self:get_log_viewers(),
    'log_replicate',
    message,
    action,
    object,
    subject,
    { type = 'colored', color = color }
  )

  pending_logs[#pending_logs + 1] = { body = message, action = action, object = object, subject = subject }
end

--- Saves the log entries that `Damage:write_log` has queued to the logs table, in the order
-- they were written. Serverside only.
-- @return [Number how many entries were saved]
function Damage:flush_logs()
  local entries = pending_logs
  local count = #entries

  if count == 0 then
    return 0
  end

  pending_logs = {}

  for i = 1, count do
    local v = entries[i]
    local log = Log.new()
      log.body = v.body
      log.action = v.action
      log.object = v.object
      log.subject = v.subject
    log:save()
  end

  return count
end

--- Writes a damage log entry: who has taken how much damage, to which limb (its English
-- name, see `Damage:get_limb_name`), from whom and with what, and the health and armor they
-- are left with. The entry is written with the 'player_damage' action and replicated to the
-- players who have the 'view_damage_logs' permission; it is saved by `Damage:flush_logs`.
-- Does not check the 'log_damage' config. Serverside only.
-- @param victim [Player player who has taken the damage]
-- @param damage_info [CTakeDamageInfo the damage]
-- @param hitgroup=HITGROUP_GENERIC [Number HITGROUP_ enum of the hit location]
function Damage:log_damage(victim, damage_info, hitgroup)
  local attacker, inflictor = damage_info:GetAttacker(), damage_info:GetInflictor()
  local kind = 'damage'

  if damage_info:IsFallDamage() then
    kind = 'fall damage'
  elseif damage_info:IsDamageType(DMG_DROWN) then
    kind = 'drowning damage'
  end

  local message = self:get_log_name(victim)..' has taken '..math.ceil(damage_info:GetDamage())..' '..kind

  if self:get_limb(hitgroup) then
    message ..= ' to the '..t(self:get_limb_name(hitgroup)):lower()
  end

  if attacker == victim then
    message ..= ' from themselves'
  elseif IsValid(attacker) then
    message ..= ' from '..self:get_log_name(attacker)
  end

  local weapon = self:get_weapon_class(attacker, inflictor, victim)

  if weapon then
    message ..= ' with '..weapon
  end

  message ..= ', leaving them at '..math_max(victim:Health(), 0)..' health'

  local armor = victim:Armor()

  if armor > 0 then
    message ..= ' and '..armor..' armor'
  end

  self:write_log(damage_log_color, message..'.', 'player_damage', get_log_id(attacker), get_log_id(victim))
end

--- Writes a kill log entry: who has died, who or what has killed them and with what. The
-- entry is written with the 'player_death' action and replicated to the players who have
-- the 'view_damage_logs' permission; it is saved by `Damage:flush_logs`. Does not check
-- the 'log_kills' config. Serverside only.
-- @param victim [Player player who has died]
-- @param inflictor [Entity entity that has dealt the fatal damage]
-- @param attacker [Entity entity responsible for the death]
function Damage:log_kill(victim, inflictor, attacker)
  local victim_name = self:get_log_name(victim)
  local message

  if attacker == victim then
    message = victim_name..' has killed themselves'
  elseif IsValid(attacker) then
    message = self:get_log_name(attacker)..' has killed '..victim_name
  else
    message = victim_name..' has died'
  end

  local weapon = self:get_weapon_class(attacker, inflictor, victim)

  if weapon then
    message ..= ' with '..weapon
  end

  self:write_log(kill_log_color, message..'.', 'player_death', get_log_id(attacker), get_log_id(victim))
end
