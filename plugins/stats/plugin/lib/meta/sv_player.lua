--- Server-side player extensions of the Stats plugin: changing the attributes and skills of
-- the character of a player and boosting its attributes.

local tonumber = tonumber
local attribute_definitions = Attributes.stored
local player_meta = FindMetaTable('Player')

--- Sets the player's level in an attribute, rounded and clamped to the attribute's min
-- and max, and networks it. Server only.
-- @param attribute_id [String]
-- @param level [Number]
-- @see [Attributes.update]
function player_meta:set_attribute(attribute_id, level)
  level = tonumber(level)

  if !level then return end

  Attributes.update(self, attribute_id, level)
end

--- Raises the player's level in an attribute. Boosts are not counted. Server only.
-- @param attribute_id [String]
-- @param amount=1 [Number levels to add]
function player_meta:increase_attribute(attribute_id, amount)
  amount = amount or 1

  self:set_attribute(attribute_id, self:get_attribute(attribute_id, true) + amount)
end

--- Lowers the player's level in an attribute. Boosts are not counted. Server only.
-- @param attribute_id [String]
-- @param amount=1 [Number levels to remove]
function player_meta:decrease_attribute(attribute_id, amount)
  amount = amount or 1

  self:set_attribute(attribute_id, self:get_attribute(attribute_id, true) - amount)
end

--- Adds a boost to the player's level in an attribute. The boost is stored on the
-- character, networked, and removed when it expires. A boost that is given an identifier
-- replaces the boosts of the attribute that carry the same identifier, and can be
-- removed with `Player:remove_attribute_boost`. Server only.
-- ```
-- -- Two extra levels of strength for five minutes.
-- target:boost_attribute('strength', 2, 300)
-- -- One level less for as long as the character is drunk.
-- target:boost_attribute('strength', -1, nil, 'drunk')
-- ```
-- @param attribute_id [String attribute to boost; ignored when it is not boostable]
-- @param value [Number levels to add, negative to take levels away]
-- @param duration=nil [Number seconds until the boost expires; it never expires if this
--   is nil or not above 0]
-- @param identifier=nil [Any name of the boost, kept as a string]
-- @return [AttributeBoost the record of the boost, or nil if it was not added]
function player_meta:boost_attribute(attribute_id, value, duration, identifier)
  local attribute_table = attribute_definitions[attribute_id]

  if !attribute_table or attribute_table.boostable == false then return end

  return Attributes.add_modifier(
    self,
    attribute_id,
    'attribute_boosts',
    AttributeBoost,
    value,
    duration,
    identifier
  )
end

--- Removes boosts from the player's character: all of them, those of one attribute,
-- those with one identifier, or the boost of one attribute with one identifier.
-- Server only.
-- ```
-- target:remove_attribute_boosts()                    -- every boost
-- target:remove_attribute_boosts('strength')          -- every boost to strength
-- target:remove_attribute_boosts(nil, 'drunk')        -- 'drunk' boosts to any attribute
-- target:remove_attribute_boosts('strength', 'drunk') -- the 'drunk' boost to strength
-- ```
-- @param attribute_id=nil [String only remove the boosts to this attribute]
-- @param identifier=nil [Any only remove the boosts with this identifier]
-- @return [Number amount of boosts removed]
function player_meta:remove_attribute_boosts(attribute_id, identifier)
  return Attributes.clear_modifiers(self, 'attribute_boosts', attribute_id, identifier)
end

--- Removes the boost with the given identifier from one attribute of the player's
-- character. Server only.
-- @param attribute_id [String]
-- @param identifier [Any identifier the boost was given]
-- @return [Boolean true if a boost was removed]
-- @see [Player#remove_attribute_boosts]
function player_meta:remove_attribute_boost(attribute_id, identifier)
  if attribute_id == nil or identifier == nil then return false end

  return self:remove_attribute_boosts(attribute_id, identifier) > 0
end

--- Sets the player's rank in a skill, rounded and clamped between 0 and the skill's max,
-- and networks it. Server only.
-- @param skill_id [String]
-- @param rank [Number]
-- @see [Skills.update]
function player_meta:set_skill(skill_id, rank)
  rank = tonumber(rank)

  if !rank then return end

  Skills.update(self, skill_id, rank)
end

--- Raises the player's rank in a skill. Server only.
-- @param skill_id [String]
-- @param amount=1 [Number ranks to add]
function player_meta:increase_skill(skill_id, amount)
  amount = amount or 1

  self:set_skill(skill_id, self:get_skill(skill_id) + amount)
end

--- Lowers the player's rank in a skill. Server only.
-- @param skill_id [String]
-- @param amount=1 [Number ranks to remove]
function player_meta:decrease_skill(skill_id, amount)
  amount = amount or 1

  self:set_skill(skill_id, self:get_skill(skill_id) - amount)
end
