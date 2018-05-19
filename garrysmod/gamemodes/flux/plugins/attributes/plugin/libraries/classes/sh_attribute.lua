--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

class "CAttribute"

function CAttribute:CAttribute(uniqueID)
  if (!isstring(uniqueID)) then return end

  self.id = uniqueID
end

function CAttribute:Register()
  return attributes.Register(self.id, self)
end

Attribute = CAttribute
