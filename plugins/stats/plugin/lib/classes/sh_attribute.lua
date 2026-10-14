--- Definition of an attribute: its name, description, category and icon, its level range
-- (`min`, `max`, `default`, and `creation_max`, the highest level a new character can pick),
-- and the `boostable`, `boost_limited` and `hidden` flags.
-- A file in a plugin's `attributes` folder fills in an `AttributeBase` through the
-- `ATTRIBUTE` global; `Attributes.register` supplies the defaults of the missing fields.
--
-- An attribute can name its levels. `levels` is a map of level IDs to the phrases that
-- describe them, `level_order` lists the level IDs from the lowest level (`min`) upwards,
-- and `level_names` optionally maps a level ID to the phrase of its name, which is
-- `attribute.level.<id>` otherwise. The default `level_order` is the nine step ladder from
-- 'terrible' through 'superb' to 'heroic' and 'legendary', which fits an attribute that goes
-- from -3 to 5.
-- ```
-- -- attributes/sh_endurance.lua
-- ATTRIBUTE.name = 'attribute.endurance.title'
-- ATTRIBUTE.min = -3
-- ATTRIBUTE.max = 5
-- ATTRIBUTE.default = 0
-- ATTRIBUTE.levels = {
--   superb = 'attribute.endurance.superb',
--   fair = 'attribute.endurance.fair',
--   terrible = 'attribute.endurance.terrible'
-- }
-- ```

class 'AttributeBase'

AttributeBase.level_order = {
  'terrible', 'poor', 'mediocre', 'fair', 'good', 'great', 'superb', 'heroic', 'legendary'
}

--- Creates an attribute definition. Fill in its fields and call register to make it available.
-- ```
-- local attribute = AttributeBase.new('strength')
-- attribute.name = 'attribute.strength.name'
-- attribute.description = 'attribute.strength.desc'
-- attribute.max = 20
-- attribute:register()
-- ```
-- @param id [String unique attribute ID; nothing is set when it is not a string]
function AttributeBase:init(id)
  if !isstring(id) then return end

  self.attribute_id = id
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
