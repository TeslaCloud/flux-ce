--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- Alternatively, you can use item.CreateBase("CItemEquippable")
class "CItemEquippable" extends CItem

CItemEquippable.Name = "Equipment Base"
CItemEquippable.Description = "This item can be equipped."

function CItemEquippable:OnEquipped(player)

end

function CItemEquippable:OnUnEquipped(player)

end

function CItemEquippable:Equip(player, bShouldEquip)
	if (bShouldEquip) then
		self:OnEquipped(player)
	else
		self:OnUnEquipped(player)
	end
end

ItemEquippable = CItemEquippable