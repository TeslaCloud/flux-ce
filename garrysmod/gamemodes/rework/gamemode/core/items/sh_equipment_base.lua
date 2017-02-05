--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

ITEM.isBase = true
ITEM.Name = "Equipment Base"
ITEM.Description = "This item can be equipped."

function ITEM:OnEquipped(player)

end

function ITEM:OnUnEquipped(player)

end

function ITEM:Equip(player, bShouldEquip)
	if (bShouldEquip) then
		self:OnEquipped(player)
	else
		self:OnUnEquipped(player)
	end
end