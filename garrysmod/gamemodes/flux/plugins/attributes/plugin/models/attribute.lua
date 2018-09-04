class 'Attribute' extends 'ActiveRecord::Base'

Attribute:belongs_to 'Character'

function Attribute:init(id)
  if !isstring(id) then return end

  self.attr_id = id
end

function Attribute:register()
  return attributes.register(self.id, self)
end
