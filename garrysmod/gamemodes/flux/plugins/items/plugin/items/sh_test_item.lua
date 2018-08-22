--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]ITEM.Name = "Test Item"
ITEM.Description = "An item that has a single purpose: system testing. Great, yeah."
ITEM.Model = "models/props_junk/metal_paintcan001a.mdl"

function ITEM:OnUse(player)
  print("player used item!")
end
