--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

ITEM.isBase = true
ITEM.Name = "Consumables Base"
ITEM.Description = "An item that can be consumed."

function ITEM:OnUse(player)
	if (hook.Run("PrePlayerConsumeItem", player, self) != false) then
		hook.Run("PlayerConsumeItem", player, self)
	end
end