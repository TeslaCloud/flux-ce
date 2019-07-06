class 'Attribute' extends 'ActiveRecord::Base'

Attribute:belongs_to 'Character'
Attribute:has_many 'attribute_multipliers'
Attribute:has_many 'attribute_boosts'

function Attribute:init(id)
  if !isstring(id) then return end

  self.attr_id = id
end

function Attribute:register()
  return Attributes.register(self.attr_id, self)
end
