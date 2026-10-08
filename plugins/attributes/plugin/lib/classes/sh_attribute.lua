--- Definition of an attribute: its name, description, category, icon and type, its level
-- range (`min`, `max`), how the progress needed for a level grows (`total_progress`,
-- `progression_type`, `progression_coefficient`), and the `boostable`, `multipliable`,
-- `boost_limited`, `has_progress` and `hidden` flags.
-- A file in a plugin's `attributes` folder fills in an `AttributeBase` through the
-- `ATTRIBUTE` global; `Attributes.register` supplies the defaults of the missing fields.

class 'AttributeBase'

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

--- Registers this attribute definition under its attribute ID.
-- @see [Attributes.register]
function AttributeBase:register()
  return Attributes.register(self.attribute_id, self)
end
