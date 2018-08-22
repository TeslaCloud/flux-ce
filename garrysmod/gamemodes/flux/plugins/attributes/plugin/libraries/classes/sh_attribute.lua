class "CAttribute"

function CAttribute:CAttribute(id)
  if (!isstring(id)) then return end

  self.id = id
end

function CAttribute:Register()
  return attributes.Register(self.id, self)
end

Attribute = CAttribute
