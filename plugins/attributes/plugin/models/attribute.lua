class 'Attribute' extends 'ActiveRecord::Base'

Attribute:belongs_to 'Character'

function Attribute:init(id)
  if !isstring(id) then return end

  self.attribute_id = id
end

function Attribute:get_total_progress(level)
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

function Attribute:register()
  return Attributes.register(self.attribute_id, self)
end
