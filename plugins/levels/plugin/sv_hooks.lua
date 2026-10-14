--- Server side of the Levels plugin: networks the level of a character when it becomes
-- active, keeps the maximum health of players in line with their level and endurance, gives
-- combat experience while the `levels_combat_experience` config is on, keeps the server level
-- up to date and brings characters in line with its level cap and level floor, and handles
-- the `fl_levels_spend_skill` and `fl_levels_spend_attribute` requests of clients.

local IsValid = IsValid
local isstring = isstring
local tonumber = tonumber
local config_get = Config.get
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_round = math.Round

local health_configs = {
  health_base = true,
  health_per_level = true
}

local point_configs = {
  levels_skill_points_per_level = true,
  levels_boost_every = true,
  levels_boost_points = true
}

local server_configs = {
  levels_server_progression = true,
  levels_server_days_per_level = true,
  levels_server_ramp_level = true,
  levels_server_ramp_days = true,
  levels_server_cap_offset = true,
  levels_server_floor_offset = true
}

--- Checks whether a player may gain combat experience: the `levels_combat_experience`
-- config is on and the entity is a player with an active character.
-- @param actor [Entity]
-- @return [Boolean]
local function can_gain_combat_experience(actor)
  return config_get('levels_combat_experience', false) == true and IsValid(actor) and
    actor:IsPlayer() and actor:is_character_loaded()
end

--- Gives a player combat experience after the AdjustCombatExperience hook has had its say.
-- @param actor [Player the player who fought]
-- @param amount [Number experience before the hook]
-- @param reason [String 'damage' or 'kill']
-- @param victim [Entity the NPC or player that was hurt or killed]
-- @param damage_info=nil [CTakeDamageInfo the damage that was dealt, nil for a kill]
local function give_combat_experience(actor, amount, reason, victim, damage_info)
  local info = {
    amount = amount,
    reason = reason,
    victim = victim,
    damage_info = damage_info
  }

  --- Lets plugins change or cancel the experience a player gains in combat while the
  -- `levels_combat_experience` config is on. Called on the server by the Levels plugin for
  -- the damage a player deals to an NPC or another player and for every NPC a player kills.
  -- Change `info.amount` to give another amount; an amount that is not above 0 gives none.
  -- ```
  -- function PLUGIN:AdjustCombatExperience(actor, info)
  --   if info.victim:IsPlayer() then
  --     info.amount = 0
  --   end
  -- end
  -- ```
  -- @param actor [Player The player who gains the experience]
  -- @param info [Map amount (Number experience to give), reason ('damage' or 'kill'),
  --   victim (Entity the NPC or player that was hurt or killed) and damage_info
  --   (CTakeDamageInfo the damage that was dealt; nil for a kill)]
  -- @return [Boolean Return false to give no experience. Return nothing to let other
  --   handlers run]
  if hook.Run('AdjustCombatExperience', actor, info) == false then return end

  amount = math_floor(tonumber(info.amount) or 0)

  if amount > 0 then
    actor:give_experience(amount, info.reason)
  end
end

--- Gives a new character level 1 and no experience, so that the record has them from the
-- moment it is first saved.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Levels:PostCreateCharacter(owner, char, char_data)
  char.level = 1
  char.experience = 0
end

--- Works out the unspent points of the character that has become active, networks its
-- level and experience, raises it to the level floor, levels it up with its kept experience
-- as far as the level cap allows and applies its maximum health.
-- @param owner [Player]
-- @param character [Character]
function Levels:OnActiveCharacterSet(owner, character)
  Levels.update_points(owner)
  Levels.sync(owner)
  Levels.apply_server_level(owner)

  self:apply_max_health(owner)
end

--- Loads the time of the first run of the plugin on this server, which the server level is
-- counted from, and checks the server level.
function Levels:LoadData()
  Levels.load_server_data()
end

--- Checks once a minute whether the server has reached a new level.
function Levels:OneMinute()
  Levels.check_server_level()
end

--- Brings the character of every player in line with the new server level: raises it to
-- the new level floor and levels it up with its kept experience as far as the new level cap
-- allows.
-- @param level [Number new server level]
-- @param old_level [Number server level before the change]
function Levels:ServerLevelChanged(level, old_level)
  for k, v in player.Iterator() do
    if v:is_character_loaded() then
      Levels.apply_server_level(v)
    end
  end
end

--- Applies the maximum health again once the Characters plugin has given the player the
-- health saved with the character, so that saved health above the maximum is cut down.
-- @param owner [Player]
-- @param character [Character]
function Levels:PostCharacterLoaded(owner, character)
  self:apply_max_health(owner)
end

--- Gives a spawning player with an active character the maximum health of their level and
-- fills their health up to it.
-- @param actor [Player]
function Levels:PlayerSpawn(actor)
  self:apply_max_health(actor, true)
end

--- Applies the maximum health of a living player again when it has changed for a reason
-- that runs no hook, such as a boost to their endurance that has been given or has expired.
-- @param actor [Player]
-- @param cur_time [Number current CurTime()]
function Levels:PlayerOneSecond(actor, cur_time)
  if !actor:Alive() or !actor:is_character_loaded() then return end

  if actor:GetMaxHealth() != self:get_max_health(actor) then
    self:apply_max_health(actor)
  end
end

--- Applies the maximum health of the new level. A player who has gone up and is alive is
-- healed by as much as the maximum has grown.
-- @param actor [Player]
-- @param level [Number new level]
-- @param old_level [Number level before the change]
function Levels:PlayerLevelChanged(actor, level, old_level)
  local old_max_health = actor:GetMaxHealth()
  local max_health = self:apply_max_health(actor)

  if max_health and max_health > old_max_health and actor:Alive() then
    actor:SetHealth(math_min(actor:Health() + max_health - old_max_health, max_health))
  end
end

--- Applies the maximum health again when the endurance of a player has changed.
-- @param actor [Player]
-- @param attribute_id [String]
-- @param level [Number]
-- @param progress [Number]
-- @param old_level [Number]
-- @param old_progress [Number]
function Levels:PlayerAttributeChanged(actor, attribute_id, level, progress, old_level, old_progress)
  if attribute_id == 'endurance' then
    self:apply_max_health(actor)
  end
end

--- Makes the Factions plugin use the maximum health of the player's level instead of the
-- one of their faction and rank.
-- @param target [Player]
-- @param max_health [Number maximum health of the faction and rank, or nil]
-- @return [Number maximum health of the player's level, nil for a player without an active
--   character]
function Levels:GetPlayerMaxHealth(target, max_health)
  if IsValid(target) and target:is_character_loaded() then
    return self:get_max_health(target)
  end
end

--- Applies the maximum health to every player when a health config changes, works out the
-- unspent points of every player again when a config of the level-up points changes, and
-- checks the server level and brings every character in line with its level cap and level
-- floor when a config of the server level changes. The hook runs before the new value is
-- stored, so the work waits for the next tick, when `Config.get` returns the new value.
-- @param key [String config key]
-- @param old_value [Any]
-- @param new_value [Any]
function Levels:OnConfigSet(key, old_value, new_value)
  if !server_configs[key] and !health_configs[key] and !point_configs[key] then return end

  timer.Simple(0, function()
    if server_configs[key] then
      Levels.check_server_level()
    end

    for k, v in player.Iterator() do
      if IsValid(v) and v:is_character_loaded() then
        if server_configs[key] then
          Levels.apply_server_level(v)
        elseif health_configs[key] then
          self:apply_max_health(v)
        else
          Levels.update_points(v)
        end
      end
    end
  end)
end

--- Gives a player experience for the damage they have dealt to an NPC or another player,
-- `levels_experience_per_damage` for every point of damage, while the
-- `levels_combat_experience` config is on. Damage beyond the maximum health of the victim
-- does not count.
-- @param entity [Entity the entity that was attacked]
-- @param damage_info [CTakeDamageInfo]
-- @param took [Boolean whether the entity has actually taken the damage]
function Levels:PostEntityTakeDamage(entity, damage_info, took)
  if !took or !IsValid(entity) or !(entity:IsNPC() or entity:IsPlayer()) then return end

  local attacker = damage_info:GetAttacker()

  if attacker == entity or !can_gain_combat_experience(attacker) then return end

  local damage = damage_info:GetDamage()
  local max_health = entity:GetMaxHealth()

  if max_health > 0 then
    damage = math_min(damage, max_health)
  end

  if damage <= 0 then return end

  local per_damage = math_max(tonumber(config_get('levels_experience_per_damage', 2)) or 0, 0)

  give_combat_experience(attacker, math_floor(damage * per_damage), 'damage', entity, damage_info)
end

--- Gives a player experience for an NPC they have killed while the
-- `levels_combat_experience` config is on: `levels_experience_per_kill`, multiplied by a
-- tenth of the maximum health of the NPC but never by less than 1.
-- @param npc [NPC the NPC that was killed]
-- @param attacker [Entity]
-- @param inflictor [Entity]
function Levels:OnNPCKilled(npc, attacker, inflictor)
  if !IsValid(npc) or !can_gain_combat_experience(attacker) then return end

  local per_kill = math_max(tonumber(config_get('levels_experience_per_kill', 50)) or 0, 0)
  local scale = math_max(npc:GetMaxHealth() / 10, 1)

  give_combat_experience(attacker, math_round(per_kill * scale), 'kill', npc)
end

Cable.receive('fl_levels_spend_skill', function(actor, skill_id)
  if !IsValid(actor) or !isstring(skill_id) then return end

  local success, phrase = actor:spend_skill_point(skill_id)

  if !success then
    actor:notify(phrase)
  end
end)

Cable.receive('fl_levels_spend_attribute', function(actor, stat_id)
  if !IsValid(actor) or !isstring(stat_id) then return end

  local success, phrase = actor:spend_attribute_point(stat_id)

  if !success then
    actor:notify(phrase)
  end
end)
