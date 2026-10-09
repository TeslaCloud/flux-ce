--- Definition of an attribute: its name, description, category, icon and type, its level
-- range (`min`, `max`, `default`), how the progress needed for a level grows
-- (`total_progress`, `progression_type`, `progression_coefficient`), and the `boostable`,
-- `multipliable`, `boost_limited`, `has_progress` and `hidden` flags.
-- A file in a plugin's `attributes` folder fills in an `AttributeBase` through the
-- `ATTRIBUTE` global; `Attributes.register` supplies the defaults of the missing fields.
--
-- An attribute can name its levels. `levels` is a map of level IDs to the phrases that
-- describe them, `level_order` lists the level IDs from the lowest level (`min`) upwards,
-- and `level_names` optionally maps a level ID to the phrase of its name, which is
-- `attribute.level.<id>` otherwise. The default `level_order` is the seven step ladder from
-- 'terrible' to 'superb', which fits an attribute that goes from -3 to 3.
-- ```
-- -- attributes/sh_endurance.lua
-- ATTRIBUTE.name = 'attribute.endurance.title'
-- ATTRIBUTE.type = ATTRIBUTE_STAT
-- ATTRIBUTE.min = -3
-- ATTRIBUTE.max = 3
-- ATTRIBUTE.default = 0
-- ATTRIBUTE.has_progress = false
-- ATTRIBUTE.levels = {
--   superb = 'attribute.endurance.superb',
--   fair = 'attribute.endurance.fair',
--   terrible = 'attribute.endurance.terrible'
-- }
-- ```

class 'AttributeBase'

AttributeBase.level_order = { 'terrible', 'poor', 'mediocre', 'fair', 'good', 'great', 'superb' }

--- Creates an attribute definition. Fill in its fields and call register to make it available.
-- ```
-- local attribute = AttributeBase.new('strength')
-- attribute.name = 'attribute.strength.name'
-- attribute.description = 'attribute.strength.desc'
-- attribute.type = ATTRIBUTE_STAT
-- attribute.max = 20
-- attribute.multipliable = true
-- attribute:register()
-- ```
-- @param id [String unique attribute ID; nothing is set when it is not a string]
function AttributeBase:init(id)
  if !isstring(id) then return end

  self.attribute_id = id
end

--- Returns how much progress is needed to advance from the given level to the next one,
-- according to the attribute's progression type and coefficient.
-- @param level [Number level to advance from]
-- @return [Number]
function AttributeBase:get_total_progress(level)
  level = level - 1

  local progress_type = self.progression_type
  local progress = self.total_progress
  local coefficient = self.progression_coefficient

  if progress_type == PROGRESSION_LINEAR then
    return progress
  elseif progress_type == PROGRESSION_ARITHMETIC then
    return math.round(progress * (1 + (coefficient - 1) * level))
  else
    return math.round(progress * coefficient ^ level)
  end
end

--- Returns the ID of the named level that a level of this attribute falls on: the entry of
-- `level_order` at the position of the level counted from `min`. A level beyond either end
-- of the list takes the first or the last entry, which is what a boost can lead to.
-- @param level [Number]
-- @return [String level ID, or nil if the attribute does not name its levels or `levels`
--   has no entry for that level]
function AttributeBase:get_level_id(level)
  local order = self.level_order

  if !istable(self.levels) or !istable(order) or #order == 0 or !isnumber(level) then return end

  local id = order[math.clamp(math.floor(level) - (self.min or 0) + 1, 1, #order)]

  if self.levels[id] != nil then
    return id
  end
end

--- Returns the phrase that names a level of this attribute, such as 'attribute.level.good'.
-- @param level [Number]
-- @return [String phrase, or nil if the attribute does not name that level]
-- @see [AttributeBase#get_level_id]
function AttributeBase:get_level_name(level)
  local id = self:get_level_id(level)

  if !id then return end

  local names = self.level_names

  return istable(names) and names[id] or 'attribute.level.'..id
end

--- Returns the phrase that describes a level of this attribute, taken from `levels`.
-- @param level [Number]
-- @return [String phrase, or nil if the attribute does not describe that level]
-- @see [AttributeBase#get_level_id]
function AttributeBase:get_level_description(level)
  local id = self:get_level_id(level)
  local description = id and self.levels[id]

  if isstring(description) then
    return description
  end
end

--- Registers this attribute definition under its attribute ID.
-- @see [Attributes.register]
function AttributeBase:register()
  return Attributes.register(self.attribute_id, self)
end
