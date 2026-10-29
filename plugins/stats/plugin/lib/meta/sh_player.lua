--- Player extensions of the Stats plugin: the attributes and skills of the character of a
-- player, their modifiers and the rolls made with them.

local tonumber = tonumber
local tostring = tostring
local isstring = isstring
local attribute_definitions = Attributes.stored
local skill_definitions = Skills.stored
local player_meta = FindMetaTable('Player')

--- Returns the level and the boosts of every attribute of the player's character. On the
-- client this is what the server has networked, which it does for the local player alone:
-- any other player has no attributes there. A boost has a value, the identifier it was
-- given (`id`), the time it expires at as a date-time string (`expires_at`) and as a
-- CurTime (`end_time`); the last three are nil when not set.
-- ```
-- local attributes = target:get_attributes()
--
-- -- attributes.strength = {
-- --   level = 3,
-- --   boosts = {
-- --     { value = 2, expires_at = '2026-01-01T12:00:00Z', end_time = 1520 },
-- --     { value = -1, id = 'drunk' }
-- --   }
-- -- }
-- ```
-- @return [Map attribute data keyed by attribute ID; empty if the player has no character
--   or, on the client, nothing has been networked yet or the player is not the local one]
function player_meta:get_attributes()
  if SERVER then
    local attributes = Attributes.to_networkable(self)

    return attributes
  end

  return self:get_nv('attributes') or {}
end

--- Returns the level and the boosts of one attribute of the player's character, in the
-- form `Player:get_attributes` describes.
-- @param attribute_id [String]
-- @return [Map attribute data, or nil if the attribute is not registered or the player's
--   character has no data for it]
function player_meta:get_attribute_data(attribute_id)
  local attribute_table = attribute_definitions[attribute_id]

  if !attribute_table then return end

  if CLIENT then
    local attributes = self:get_nv('attributes')

    return attributes and attributes[attribute_id]
  end

  return Attributes.get_data(self, attribute_id)
end

--- Returns the player's level in an attribute. Active boosts are added to the level unless
-- disabled or the attribute is not boostable. A player whose character has no data for the
-- attribute, such as a bot, is at the attribute's default level.
-- @param attribute_id [String]
-- @param no_boost=false [Boolean leave active boosts out of the level]
-- @return [Number level; 0 if the attribute is not registered]
function player_meta:get_attribute(attribute_id, no_boost)
  local attribute_table = attribute_definitions[attribute_id]

  if !attribute_table then return 0 end

  if SERVER then
    local level, boost = Attributes.get_level(self, attribute_id)

    if !level then
      return attribute_table.default
    end

    if no_boost or attribute_table.boostable == false then
      return level
    end

    return level + boost
  end

  local attribute = self:get_attribute_data(attribute_id)

  if !attribute then
    return attribute_table.default
  end

  local level = attribute.level or attribute_table.default
  local boost = 0

  if !no_boost and attribute_table.boostable != false then
    boost = Attributes.sum_boosts(attribute_table, attribute)
  end

  return level + boost
end

--- Returns the sum of the player's active boosts to an attribute. The server leaves an
-- expired boost out and takes it out of the networked data, so on the client every
-- networked boost counts. If the attribute has boost_limited set, the sum is cut down so
-- that the level together with the boost stays between the attribute's min and max.
-- @param attribute_id [String]
-- @return [Number]
function player_meta:get_attribute_boost(attribute_id)
  local attribute_table = attribute_definitions[attribute_id]
  local attribute = attribute_table and self:get_attribute_data(attribute_id)

  if !attribute then return 0 end

  return Attributes.sum_boosts(attribute_table, attribute)
end

--- Returns the player's active boosts to an attribute.
-- @param attribute_id [String]
-- @return [List<Map> boosts, each with value and, when set, id, expires_at and end_time]
-- @see [Player#get_attributes]
function player_meta:get_attribute_boosts(attribute_id)
  local attribute = self:get_attribute_data(attribute_id)

  return attribute and attribute.boosts or {}
end

--- Checks whether the player has an active boost with the given identifier.
-- @param attribute_id [String]
-- @param identifier [Any identifier the boost was given, compared as a string]
-- @return [Boolean]
function player_meta:has_attribute_boost(attribute_id, identifier)
  if identifier == nil then return false end

  identifier = tostring(identifier)

  for _, boost in pairs(self:get_attribute_boosts(attribute_id)) do
    if boost.id == identifier then
      return true
    end
  end

  return false
end

--- Returns the rank of every skill of the player's character. On the client this is what
-- the server has networked, which it does for the local player alone: any other player has
-- no skills there.
-- ```
-- local skills = target:get_skills()
--
-- -- skills.athletics = 2
-- ```
-- @return [Map ranks keyed by skill ID; empty if the player has no character or, on the
--   client, nothing has been networked yet or the player is not the local one]
function player_meta:get_skills()
  if SERVER then
    return Skills.to_networkable(self)
  end

  return self:get_nv('skills') or {}
end

--- Returns the player's rank in a skill. A player whose character has no record for the
-- skill, such as a bot, is at rank 0.
-- @param skill_id [String]
-- @return [Number rank; 0 if the skill is not registered]
function player_meta:get_skill(skill_id)
  if !skill_definitions[skill_id] then return 0 end

  if CLIENT then
    local skills = self:get_nv('skills')

    return skills and tonumber(skills[skill_id]) or 0
  end

  local record = Skills.get_record(self:is_character_loaded() and self:get_character(), skill_id)

  return record and tonumber(record.rank) or 0
end

--- Returns the modifier that an attribute adds to the player's rolls: its level, boosts
-- included.
-- @param stat_id [String ID of the stat]
-- @return [Number 0 if the attribute is not registered]
function player_meta:get_attribute_modifier(stat_id)
  if !Attributes.find(stat_id) then
    return 0
  end

  return self:get_attribute(stat_id)
end

--- Returns the modifier that a skill adds to the player's rolls: the modifier of the key
-- stat of the skill plus the player's proficiency in it.
-- @param skill_id [String ID of the skill]
-- @return [Number 0 if the skill is not registered]
-- @see [Stats:get_proficiency]
function player_meta:get_skill_modifier(skill_id)
  local skill = Skills.find(skill_id)

  if !skill then
    return 0
  end

  local modifier = Stats:get_proficiency(self, skill_id)

  if isstring(skill.attribute) then
    modifier += self:get_attribute_modifier(skill.attribute)
  end

  return modifier
end

--- Rolls a stat for the player: a d20 plus the modifier of the stat, after the
-- AdjustAttributeRoll hook.
-- ```
-- local result = target:roll_attribute('strength')
--
-- if result and result.total >= 15 then
--   door:Fire('Unlock')
-- end
-- ```
-- @param stat_id [String ID of the stat]
-- @return [Map the result of `Dice.roll`, or nil and String the reason if nothing was
--   rolled]
function player_meta:roll_attribute(stat_id)
  if !Attributes.find(stat_id) then
    return nil, t('error.stats.not_stat', { name = tostring(stat_id) })
  end

  return Stats:roll(self, stat_id, 'attribute', self:get_attribute_modifier(stat_id))
end

--- Rolls a skill for the player: a d20 plus the modifier of the skill, after the
-- AdjustAttributeRoll hook.
-- @param skill_id [String ID of the skill]
-- @return [Map the result of `Dice.roll`, or nil and String the reason if nothing was
--   rolled]
-- @see [Player#get_skill_modifier]
function player_meta:roll_skill(skill_id)
  if !Skills.find(skill_id) then
    return nil, t('error.stats.not_skill', { name = tostring(skill_id) })
  end

  return Stats:roll(self, skill_id, 'skill', self:get_skill_modifier(skill_id))
end
