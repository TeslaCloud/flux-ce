--- Levels and experience of characters, the points that level-ups grant and the maximum
-- health that grows with the level, together with the player methods that read and change
-- them.
--
-- The level and the experience of a character live in its `level` and `experience` fields
-- on the server, and the server networks them to the owner of the character alone, in the
-- private 'level' and 'experience' networked variables, which the getters read on the
-- client. The skill and attribute points that have not been spent yet are kept in the
-- `skill_points` and `attribute_points` character data, which the owner receives as well,
-- and the points spent so far in `skill_points_spent` and `attribute_points_spent`, which
-- stay on the server. What is unspent is always worked out from the level: the points the
-- level has earned minus the points already spent, never less than zero.
--
-- This file is included before sh_plugin.lua, which is why it is the one that makes the
-- plugin available as the `Levels` global.

local IsValid = IsValid
local isstring = isstring
local istable = istable
local tonumber = tonumber
local config_get = Config.get
local math_clamp = math.clamp
local math_floor = math.floor
local math_max = math.max
local math_round = math.Round

if !Levels then
  PLUGIN:set_global('Levels')
end

Characters.network_data('skill_points')
Characters.network_data('attribute_points')

--- Reads a config as a whole number that is not lower than a minimum.
-- @param key [String config key]
-- @param default [Number value to use while the config has no valid value]
-- @param min [Number lowest value to return]
-- @return [Number]
local function get_whole_config(key, default, min)
  local value = tonumber(config_get(key, default))

  if !value or value != value then
    value = default
  end

  return math_max(math_floor(value), min)
end

--- Returns the highest level a character can reach, the `levels_max_level` config.
-- @return [Number never lower than 1]
function Levels.get_max_level()
  return get_whole_config('levels_max_level', 20, 1)
end

--- Returns the experience needed to go from a level to the next one: the
-- `levels_experience_per_level` config, the same for every level. A character at the
-- highest level has no next level to gather experience for.
-- @param level [Number level to go up from]
-- @return [Number experience; 0 when the level is the highest one or above it]
function Levels.get_experience_for_level(level)
  level = tonumber(level) or 1

  if level >= Levels.get_max_level() then
    return 0
  end

  return get_whole_config('levels_experience_per_level', 1000, 1)
end

--- Returns the skill points that a character has earned by reaching a level:
-- `levels_skill_points_per_level` for every level after the first.
-- @param level [Number]
-- @return [Number]
function Levels.get_skill_points_for_level(level)
  local per_level = get_whole_config('levels_skill_points_per_level', 1, 0)

  return math_max(math_floor(tonumber(level) or 1) - 1, 0) * per_level
end

--- Returns the attribute points that a character has earned by reaching a level:
-- `levels_boost_points` for every `levels_boost_every` levels, so with the defaults 2
-- points at levels 5, 10, 15 and 20.
-- @param level [Number]
-- @return [Number]
function Levels.get_attribute_points_for_level(level)
  local every = get_whole_config('levels_boost_every', 5, 0)

  if every < 1 then return 0 end

  local points = get_whole_config('levels_boost_points', 2, 0)

  return math_floor(math_max(math_floor(tonumber(level) or 1), 0) / every) * points
end

--- Returns the maximum health of a player's character:
-- `health_base + (level - 1) * health_per_level + level * endurance`, where endurance is
-- the level of the 'endurance' stat with its boosts, or 0 when no such stat is registered.
-- With the defaults a level 1 character of endurance 0 has 10 health and gains 3 for each
-- level after that.
-- @param target [Player]
-- @return [Number whole number, never lower than 1]
function Levels:get_max_health(target)
  local level = target:get_level()
  local endurance = tonumber((target:get_attribute('endurance'))) or 0
  local base = get_whole_config('health_base', 10, 1)
  local per_level = get_whole_config('health_per_level', 3, 0)

  return math_max(math_floor(base + (level - 1) * per_level + level * endurance), 1)
end

if SERVER then
  --- Returns the active character of a player, if they have one.
  -- @param target [Player]
  -- @return [Character/Map the character record, or the stand-in table of a bot; nil if the
  --   player is not valid or has no active character]
  local function get_character(target)
    if !IsValid(target) or !target:is_character_loaded() then return end

    local character = target:get_character()

    return istable(character) and character or nil
  end

  --- Returns the level stored on a character, kept between 1 and the highest level.
  -- @param character [Character]
  -- @return [Number]
  local function get_stored_level(character)
    local level = tonumber(character.level) or 1

    return math_clamp(math_floor(level), 1, Levels.get_max_level())
  end

  --- Returns the experience stored on a character.
  -- @param character [Character]
  -- @return [Number never lower than 0]
  local function get_stored_experience(character)
    return math_max(math_floor(tonumber(character.experience) or 0), 0)
  end

  --- Networks the level and the experience of a player's character to that player, in the
  -- private 'level' and 'experience' networked variables. Called after every change the
  -- plugin makes and when a character becomes active; call it yourself after changing the
  -- fields of the character directly. Server only.
  -- @param target [Player]
  function Levels.sync(target)
    local character = get_character(target)

    if !character then return end

    target:set_private_nv('level', get_stored_level(character))
    target:set_private_nv('experience', get_stored_experience(character))
  end

  --- Works out the unspent skill and attribute points of a player's character from its
  -- level and stores them in the `skill_points` and `attribute_points` character data: the
  -- points the level has earned minus the points spent so far, never less than zero. Points
  -- that were spent stay spent when the level goes down. Server only.
  -- @param target [Player]
  function Levels.update_points(target)
    if !get_character(target) then return end

    local level = target:get_level()
    local skill_points = math_max(Levels.get_skill_points_for_level(level) -
      (tonumber(target:get_character_data('skill_points_spent')) or 0), 0)
    local attribute_points = math_max(Levels.get_attribute_points_for_level(level) -
      (tonumber(target:get_character_data('attribute_points_spent')) or 0), 0)

    if target:get_character_data('skill_points') != skill_points then
      target:set_character_data('skill_points', skill_points)
    end

    if target:get_character_data('attribute_points') != attribute_points then
      target:set_character_data('attribute_points', attribute_points)
    end
  end

  --- Sets the level and the experience of a player's character, works out its unspent
  -- points again, networks the change and runs the PlayerExperienceChanged hook, followed
  -- by PlayerLevelChanged when the level has changed. A character at the highest level
  -- keeps no experience. Nothing happens if neither value changes. Server only.
  -- @param target [Player]
  -- @param level [Number new level, rounded and kept between 1 and the highest level]
  -- @param experience [Number new experience toward the next level, rounded down and never
  --   lower than 0]
  -- @param reason=nil [String what the change is for, passed on to the hook]
  -- @return [Boolean true if the level or the experience has changed]
  function Levels.update(target, level, experience, reason)
    local character = get_character(target)

    if !character then return false end

    local max_level = Levels.get_max_level()

    level = tonumber(level) or 1
    experience = tonumber(experience) or 0

    if level != level or experience != experience then return false end

    level = math_clamp(math_round(level), 1, max_level)
    experience = level >= max_level and 0 or math_max(math_floor(experience), 0)

    local old_level = get_stored_level(character)
    local old_experience = get_stored_experience(character)

    if level == old_level and experience == old_experience then return false end

    character.level = level
    character.experience = experience

    Levels.update_points(target)
    Levels.sync(target)

    --- Called on the server after the level or the experience of a player's character has
    -- changed and the change has been networked, however it came about: through
    -- `Player:give_experience`, `Player:set_level` or the staff commands. A call that moves
    -- the character over several levels runs the hook once.
    -- @param actor [Player The player whose character it is]
    -- @param experience [Number New experience toward the next level]
    -- @param old [Number Experience toward the next level before the change, which may have
    --   been a lower level]
    -- @param reason [String What the experience was given for: 'damage' and 'kill' for
    --   combat experience, 'command' for the CharGiveExperience command, 'level_set' when
    --   the level was set, or whatever the caller of `Player:give_experience` passed; may be
    --   nil]
    hook.Run('PlayerExperienceChanged', target, experience, old_experience, reason)

    if level != old_level then
      --- Called on the server after the level of a player's character has changed, right
      -- after PlayerExperienceChanged. Its unspent points have already been worked out
      -- again. A call that moves the character over several levels runs the hook once. The
      -- Levels plugin applies the new maximum health from its own handler.
      -- @param actor [Player The player whose character it is]
      -- @param level [Number New level]
      -- @param old_level [Number Level before the change]
      hook.Run('PlayerLevelChanged', target, level, old_level)
    end

    return true
  end

  --- Sets the maximum health of a player to `Levels:get_max_health`. Their health is cut
  -- down to it if it is higher, or set to it if asked to refill. Nothing happens to a player
  -- without an active character. Server only.
  -- @param target [Player]
  -- @param refill=false [Boolean also fill the health of the player up to the maximum]
  -- @return [Number the maximum health applied, or nil if nothing was done]
  function Levels:apply_max_health(target, refill)
    if !get_character(target) then return end

    local max_health = self:get_max_health(target)

    target:SetMaxHealth(max_health)

    if refill or target:Health() > max_health then
      target:SetHealth(max_health)
    end

    return max_health
  end
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the level of the player's character. On the client this is what the server has
  -- networked, which it does for the local player alone.
  -- @return [Number between 1 and the highest level; 1 when the player has no character or,
  --   on the client, is not the local player]
  function player_meta:get_level()
    local level

    if CLIENT then
      level = self:get_nv('level')
    elseif self:is_character_loaded() then
      local character = self:get_character()

      level = istable(character) and character.level
    end

    return math_clamp(math_floor(tonumber(level) or 1), 1, Levels.get_max_level())
  end

  --- Returns the experience the player's character has gathered toward its next level. On
  -- the client this is what the server has networked, which it does for the local player
  -- alone.
  -- @return [Number; 0 when the player has no character, is at the highest level or, on the
  --   client, is not the local player]
  function player_meta:get_experience()
    local experience

    if CLIENT then
      experience = self:get_nv('experience')
    elseif self:is_character_loaded() then
      local character = self:get_character()

      experience = istable(character) and character.experience
    end

    return math_max(math_floor(tonumber(experience) or 0), 0)
  end

  --- Returns the experience the player's character still needs to reach its next level.
  -- @return [Number; 0 at the highest level]
  function player_meta:get_experience_to_level()
    return math_max(Levels.get_experience_for_level(self:get_level()) - self:get_experience(), 0)
  end

  --- Returns the skill points of the player's character that have not been spent yet. On the
  -- client only the local player's points are known.
  -- @return [Number]
  function player_meta:get_skill_points()
    return math_max(tonumber(self:get_character_data('skill_points', 0)) or 0, 0)
  end

  --- Returns the attribute points of the player's character that have not been spent yet. On
  -- the client only the local player's points are known.
  -- @return [Number]
  function player_meta:get_attribute_points()
    return math_max(tonumber(self:get_character_data('attribute_points', 0)) or 0, 0)
  end

  if SERVER then
    --- Gives the player's character experience. Whenever the experience reaches what the
    -- level needs, the character goes up a level and keeps the rest, as many times as the
    -- amount allows; a negative amount takes experience away and takes levels back once the
    -- experience falls below 0, down to level 1. At the highest level no experience is
    -- kept. The player is told about every level gained. Server only.
    -- ```
    -- target:give_experience(250, 'quest')
    -- ```
    -- @param amount [Number experience, rounded; negative to take experience away]
    -- @param reason=nil [String what the experience is for, passed on to the
    --   PlayerExperienceChanged hook]
    -- @return [Boolean true if the level or the experience has changed]
    -- @see [Levels.update]
    function player_meta:give_experience(amount, reason)
      amount = tonumber(amount)

      if !amount or amount != amount or !self:is_character_loaded() then return false end

      amount = math_round(amount)

      if amount == 0 then return false end

      local old_level = self:get_level()
      local max_level = Levels.get_max_level()
      local level = old_level
      local experience = self:get_experience() + amount

      while level < max_level do
        local needed = Levels.get_experience_for_level(level)

        if needed <= 0 or experience < needed then break end

        experience = experience - needed
        level = level + 1
      end

      while experience < 0 and level > 1 do
        level = level - 1
        experience = experience + Levels.get_experience_for_level(level)
      end

      if !Levels.update(self, level, experience, reason) then return false end

      if level > old_level then
        self:notify('notification.levels.level_up', { level = level })
      end

      return true
    end

    --- Sets the level of the player's character and resets its experience to 0. The
    -- unspent skill and attribute points are worked out again for the new level, so they
    -- grow or shrink with it; points that were already spent stay spent. Server only.
    -- @param level [Number new level, rounded and kept between 1 and the highest level]
    -- @return [Boolean true if the level or the experience has changed]
    -- @see [Levels.update]
    function player_meta:set_level(level)
      level = tonumber(level)

      if !level then return false end

      local changed = Levels.update(self, level, 0, 'level_set')

      Levels.update_points(self)

      return changed
    end

    --- Spends one unspent point on an attribute of a type, raising it by one level.
    -- @param target [Player]
    -- @param attribute_id [String]
    -- @param attribute_type [Number ATTRIBUTE_SKILL or ATTRIBUTE_STAT]
    -- @param pool_key [String character data key of the unspent points]
    -- @param errors [Map phrases to return: invalid, empty and maxed]
    -- @return [Boolean true if the point was spent, String phrase of the reason otherwise]
    local function spend_point(target, attribute_id, attribute_type, pool_key, errors)
      if !target:is_character_loaded() then
        return false, 'error.levels.no_active_character'
      end

      local attribute = isstring(attribute_id) and Attributes.find(attribute_id)

      if !attribute or attribute.type != attribute_type then
        return false, errors.invalid
      end

      local points = math_max(tonumber(target:get_character_data(pool_key, 0)) or 0, 0)

      if points <= 0 then
        return false, errors.empty
      end

      local level = target:get_attribute(attribute_id, true)

      if level >= attribute.max then
        return false, errors.maxed
      end

      target:increase_attribute(attribute_id, 1)

      if target:get_attribute(attribute_id, true) <= level then
        return false, 'error.levels.cannot_raise'
      end

      local spent_key = pool_key..'_spent'

      target:set_character_data(pool_key, points - 1)
      target:set_character_data(spent_key, (tonumber(target:get_character_data(spent_key, 0)) or 0) + 1)

      return true
    end

    --- Spends one unspent skill point of the player's character on a skill (an attribute of
    -- type ATTRIBUTE_SKILL), raising it by one rank. Refused when the skill is not
    -- registered, the character has no skill points left or the skill is at its highest
    -- rank. Server only.
    -- @param skill_id [String attribute ID of the skill]
    -- @return [Boolean true if the point was spent, String phrase of the reason otherwise:
    --   'error.levels.no_active_character', 'error.levels.invalid_skill',
    --   'error.levels.no_skill_points', 'error.levels.skill_maxed' or
    --   'error.levels.cannot_raise']
    function player_meta:spend_skill_point(skill_id)
      return spend_point(self, skill_id, ATTRIBUTE_SKILL, 'skill_points', {
        invalid = 'error.levels.invalid_skill',
        empty = 'error.levels.no_skill_points',
        maxed = 'error.levels.skill_maxed'
      })
    end

    --- Spends one unspent attribute point of the player's character on a stat (an attribute
    -- of type ATTRIBUTE_STAT), raising it by one level. Refused when the stat is not
    -- registered, the character has no attribute points left or the stat is at its highest
    -- level. Server only.
    -- @param stat_id [String attribute ID of the stat]
    -- @return [Boolean true if the point was spent, String phrase of the reason otherwise:
    --   'error.levels.no_active_character', 'error.levels.invalid_stat',
    --   'error.levels.no_attribute_points', 'error.levels.stat_maxed' or
    --   'error.levels.cannot_raise']
    function player_meta:spend_attribute_point(stat_id)
      return spend_point(self, stat_id, ATTRIBUTE_STAT, 'attribute_points', {
        invalid = 'error.levels.invalid_stat',
        empty = 'error.levels.no_attribute_points',
        maxed = 'error.levels.stat_maxed'
      })
    end
  end
end
