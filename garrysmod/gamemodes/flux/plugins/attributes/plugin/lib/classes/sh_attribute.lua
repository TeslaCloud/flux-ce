class "CAttribute"

function CAttribute:CAttribute(id)
  if (!isstring(id)) then return end

  self.id = id
end

function CAttribute:register()
  return attributes.register(self.id, self)
end

Attribute = CAttribute
