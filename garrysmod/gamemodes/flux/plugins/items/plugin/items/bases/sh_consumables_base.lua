--[[
  Flux � 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

if (!CItemUsable) then
  util.Include("sh_usable_base.lua")
end

-- Alternatively, you can use item.CreateBase("CItemConsumable")
class "CItemConsumable" extends "CItemUsable"

CItemConsumable.Name = "Consumables Base"
CItemConsumable.Description = "An item that can be consumed."
CItemConsumable.Category = "#Item_Category_Consumables"

function CItemConsumable:OnUse(player)
  if (hook.Run("PrePlayerConsumeItem", player, self) != false) then
    hook.Run("PlayerConsumeItem", player, self)
  end
end

ItemConsumable = CItemConsumable
