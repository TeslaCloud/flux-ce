--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]class "CAttribute"

function CAttribute:CAttribute(id)
  if (!isstring(id)) then return end

  self.id = id
end

function CAttribute:Register()
  return attributes.Register(self.id, self)
end

Attribute = CAttribute
