class "Attribute"

function Attribute:init(id)
  if (!isstring(id)) then return end

  self.id = id
end

function Attribute:register()
  return attributes.register(self.id, self)
end
