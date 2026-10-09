--- Server side of the Damage plugin: the rules it applies to players.
-- Looks up the multiplier of a hit location, remembers where a player has just been hit,
-- regenerates health, hurts players who stay under water, punches the view of a player who
-- is hurt and writes the damage and kill log entries. The hooks that call these functions
-- are in `sv_hooks.lua`.
--
-- The log entries are printed and replicated the moment they are written, but they are
-- saved to the database in one go by `Damage:flush_logs`, which runs once a second and
-- when a player dies, so that a hit does not cost a database insert of its own.

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

--- Names of the hit locations as they are written to the damage log.
local hitgroup_names = {
  [HITGROUP_HEAD] = 'head',
  [HITGROUP_CHEST] = 'chest',
  [HITGROUP_STOMACH] = 'stomach',
  [HITGROUP_LEFTARM] = 'left arm',
  [HITGROUP_RIGHTARM] = 'right arm',
  [HITGROUP_LEFTLEG] = 'left leg',
  [HITGROUP_RIGHTLEG] = 'right leg'
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

  return Config.get(key, 1)
end

--- Remembers the location of the hit a player is about to take damage from. The engine only
-- reports it to `ScalePlayerDamage`, so it is kept for the `EntityTakeDamage` and
-- `PostEntityTakeDamage` handlers that follow in the same tick. Serverside only.
-- @param victim [Player]
-- @param hitgroup [Number HITGROUP_ enum]
function Damage:set_hitgroup(victim, hitgroup)
  victim.damage_hitgroup = hitgroup
  victim.damage_hitgroup_time = CurTime()
end

--- Returns the location of the hit behind the damage a player is taking right now.
-- Only meaningful while that damage is being processed, that is inside of
-- `PrePlayerTakeDamage`, `EntityTakeDamage` and `PostPlayerTakeDamage` handlers.
-- Serverside only.
-- @param victim [Player]
-- @return [Number HITGROUP_ enum; HITGROUP_GENERIC when the damage does not come from a
--   bullet or melee hit, e.g. a fall, an explosion or drowning]
function Damage:get_hitgroup(victim)
  if victim.damage_hitgroup and victim.damage_hitgroup_time == CurTime() then
    return victim.damage_hitgroup
  end

  return HITGROUP_GENERIC
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
  local share = target:Health() / math.max(target:GetMaxHealth(), 1) * 100

  if share >= Config.get('health_regen_fast_share', 50) then
    return Config.get('health_regen_fast_interval', 5)
  end

  return Config.get('health_regen_interval', 10)
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

  local amount = Config.get('health_regen_amount', 2)

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

  return math.max(CurTime() - target.submerged_since, 0)
end

--- Deals drowning damage to a player. The damage is of the DMG_DROWN type with the world as
-- its attacker, ignores armor, and goes through the usual damage hooks. Serverside only.
-- @param target [Player]
-- @param amount [Number damage to deal]
function Damage:deal_drowning_damage(target, amount)
  local world = game.GetWorld()
  local damage_info = DamageInfo()

  damage_info:SetDamage(amount)
  damage_info:SetDamageType(DMG_DROWN)
  damage_info:SetAttacker(world)
  damage_info:SetInflictor(world)

  target:TakeDamageInfo(damage_info)
end

--- Runs the drowning of a player: keeps track of how long they have been completely under
-- water and, once that exceeds the 'drowning_time' config, deals the 'drowning_damage'
-- config to them every 'drowning_interval' seconds until they surface. Dead and noclipping
-- players are left alone. Does not check the 'drowning' config. Serverside only.
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

  if cur_time - target.submerged_since < Config.get('drowning_time', 20) then return end
  if target.next_drown_damage and target.next_drown_damage > cur_time then return end

  target.next_drown_damage = cur_time + Config.get('drowning_interval', 1)

  --- Asks whether a player who has run out of breath takes drowning damage. Called on the
  -- server each time the damage is due, that is every 'drowning_interval' seconds while the
  -- player has been completely under water for longer than the 'drowning_time' config.
  -- Only runs while the 'drowning' config is on.
  -- @param target [Player The player who is drowning]
  -- @return [Boolean Return false to spare the player this time, e.g. for a breathing
  --   apparatus. Return nothing to let other handlers decide]
  if hook.Run('PlayerCanDrown', target) == false then return end

  self:deal_drowning_damage(target, Config.get('drowning_damage', 7))
end

--- Punches the view of a player by a random angle that grows with the damage: the damage
-- times the 'damage_view_punch_scale' config in degrees at most, and never more than 30
-- degrees. Serverside only.
-- @param target [Player]
-- @param damage [Number damage the player has taken]
function Damage:punch_view(target, damage)
  local amount = math.min(damage * Config.get('damage_view_punch_scale', 1), max_view_punch)

  if amount <= 0 then return end

  target:ViewPunch(Angle(
    math.Rand(-amount, amount),
    math.Rand(-amount, amount),
    math.Rand(-amount, amount) * 0.5
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

  for k, v in player.Iterator() do
    if v:can('view_damage_logs') then
      table.insert(log_viewers, v)
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

  table.insert(pending_logs, { body = message, action = action, object = object, subject = subject })
end

--- Saves the log entries that `Damage:write_log` has queued to the logs table, in the order
-- they were written. Serverside only.
-- @return [Number how many entries were saved]
function Damage:flush_logs()
  local entries = pending_logs

  if #entries == 0 then
    return 0
  end

  pending_logs = {}

  for k, v in ipairs(entries) do
    local log = Log.new()
      log.body = v.body
      log.action = v.action
      log.object = v.object
      log.subject = v.subject
    log:save()
  end

  return #entries
end

--- Writes a damage log entry: who has taken how much damage, where, from whom and with
-- what, and the health and armor they are left with. The entry is written with the
-- 'player_damage' action and replicated to the players who have the 'view_damage_logs'
-- permission; it is saved by `Damage:flush_logs`. Does not check the 'log_damage' config.
-- Serverside only.
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
  local location = hitgroup_names[hitgroup]

  if location then
    message = message..' to the '..location
  end

  if attacker == victim then
    message = message..' from themselves'
  elseif IsValid(attacker) then
    message = message..' from '..self:get_log_name(attacker)
  end

  local weapon = self:get_weapon_class(attacker, inflictor, victim)

  if weapon then
    message = message..' with '..weapon
  end

  message = message..', leaving them at '..math.max(victim:Health(), 0)..' health'

  if victim:Armor() > 0 then
    message = message..' and '..victim:Armor()..' armor'
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
    message = message..' with '..weapon
  end

  self:write_log(kill_log_color, message..'.', 'player_death', get_log_id(attacker), get_log_id(victim))
end
