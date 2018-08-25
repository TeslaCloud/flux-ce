--[[
  Flux � 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

if (!ItemUsable) then
  util.include("sh_usable_base.lua")
end

-- Alternatively, you can use item.CreateBase("ItemConsumable")
class 'ItemConsumable' extends 'ItemUsable'

ItemConsumable.name = "Consumables Base"
ItemConsumable.description = "An item that can be consumed."
ItemConsumable.category = "#Item_Category_Consumables"

function ItemConsumable:on_use(player)
  if (hook.Run("PrePlayerConsumeItem", player, self) != false) then
    hook.Run("PlayerConsumeItem", player, self)
  end
end
