--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

class "CAttribute"

function CAttribute:CAttribute(id)
  if (!isstring(id)) then return end

  self.id = id
end

function CAttribute:Register()
  return attributes.Register(self.id, self)
end

Attribute = CAttribute