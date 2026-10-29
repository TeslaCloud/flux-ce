--- Server-side player extensions of the Levels plugin: setting the level of the character of
-- a player, giving it experience and spending its skill and attribute points.

local isstring = isstring
local tonumber = tonumber
local math_max = math.max
local math_round = math.Round
local player_meta = FindMetaTable('Player')

--- Gives the player's character experience. Whenever the experience reaches what the
-- level needs, the character goes up a level and keeps the rest, as many times as the
-- amount allows, but never past the level cap (`Levels.get_level_cap`): a character at
-- the cap keeps all the experience it is given, even more than the level needs, and
-- spends it on levels once the cap rises (`Levels.catch_up`). A negative amount takes
-- experience away and takes levels back once the experience falls below 0, down to level
-- 1. At the highest level no experience is kept. The player is told about every level
-- gained. Server only.
-- ```
-- target:give_experience(250, 'quest')
-- ```
-- @param amount [Number experience, rounded; negative to take experience away]
-- @param reason=nil [String what the experience is for, passed on to the
--   PlayerExperienceChanged hook]
-- @param ignore_cap=false [Boolean level up past the level cap, as far as the highest
--   level; the staff commands do this]
-- @return [Boolean true if the level or the experience has changed]
-- @see [Levels.update]
function player_meta:give_experience(amount, reason, ignore_cap)
  amount = tonumber(amount)

  if !amount or amount != amount or !self:is_character_loaded() then return false end

  amount = math_round(amount)

  if amount == 0 then return false end

  local old_level = self:get_level()
  local cap = ignore_cap and Levels.get_max_level() or Levels.get_level_cap()
  local level, experience = Levels.advance(old_level, self:get_experience() + amount, cap)

  while experience < 0 and level > 1 do
    level -= 1
    experience += Levels.get_experience_for_level(level)
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

--- Spends one unspent point on a skill or a stat, raising it by one.
-- @param target [Player]
-- @param id [String ID of the skill or the stat]
-- @param pool_key [String character data key of the unspent points]
-- @param handlers [Map functions that work on the skill or the stat: find (taking the ID
--   and returning the definition, nil if it is not registered), get (taking the player
--   and the ID and returning the Number current value without boosts) and raise (taking
--   the player and the ID and raising the value by one)]
-- @param errors [Map phrases to return: invalid, empty and maxed]
-- @return [Boolean true if the point was spent, String phrase of the reason otherwise]
local function spend_point(target, id, pool_key, handlers, errors)
  if !target:is_character_loaded() then
    return false, 'error.levels.no_active_character'
  end

  local definition = isstring(id) and handlers.find(id)

  if !definition or definition.hidden then
    return false, errors.invalid
  end

  local points = math_max(tonumber(target:get_character_data(pool_key, 0)) or 0, 0)

  if points <= 0 then
    return false, errors.empty
  end

  local value = handlers.get(target, id)

  if value >= definition.max then
    return false, errors.maxed
  end

  handlers.raise(target, id)

  if handlers.get(target, id) <= value then
    return false, 'error.levels.cannot_raise'
  end

  local spent_key = pool_key..'_spent'

  target:set_character_data(pool_key, points - 1)
  target:set_character_data(spent_key, (tonumber(target:get_character_data(spent_key, 0)) or 0) + 1)

  return true
end

local skill_handlers = {
  find = id -> Skills.find(id),
  get = |target, id| -> target:get_skill(id),
  raise = function(target, id) target:increase_skill(id, 1) end
}

local attribute_handlers = {
  find = id -> Attributes.find(id),
  get = |target, id| -> target:get_attribute(id, true),
  raise = function(target, id) target:increase_attribute(id, 1) end
}

--- Spends one unspent skill point of the player's character on a skill of the Stats
-- plugin, raising it by one rank. Refused when the skill is not registered or is hidden,
-- the character has no skill points left or the skill is at its highest rank. Server
-- only.
-- @param skill_id [String ID of the skill]
-- @return [Boolean true if the point was spent, String phrase of the reason otherwise:
--   'error.levels.no_active_character', 'error.levels.invalid_skill',
--   'error.levels.no_skill_points', 'error.levels.skill_maxed' or
--   'error.levels.cannot_raise']
function player_meta:spend_skill_point(skill_id)
  return spend_point(self, skill_id, 'skill_points', skill_handlers, {
    invalid = 'error.levels.invalid_skill',
    empty = 'error.levels.no_skill_points',
    maxed = 'error.levels.skill_maxed'
  })
end

--- Spends one unspent attribute point of the player's character on a stat of the Stats
-- plugin, raising it by one level. Refused when the stat is not registered or is hidden,
-- the character has no attribute points left or the stat is at its highest level. Server
-- only.
-- @param stat_id [String attribute ID of the stat]
-- @return [Boolean true if the point was spent, String phrase of the reason otherwise:
--   'error.levels.no_active_character', 'error.levels.invalid_stat',
--   'error.levels.no_attribute_points', 'error.levels.stat_maxed' or
--   'error.levels.cannot_raise']
function player_meta:spend_attribute_point(stat_id)
  return spend_point(self, stat_id, 'attribute_points', attribute_handlers, {
    invalid = 'error.levels.invalid_stat',
    empty = 'error.levels.no_attribute_points',
    maxed = 'error.levels.stat_maxed'
  })
end
