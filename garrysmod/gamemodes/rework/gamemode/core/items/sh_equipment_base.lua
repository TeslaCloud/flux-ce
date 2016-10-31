--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

Class("CEquipmentBase", CItem)

function CEquipmentBase:OnEquipped(player)

end;

function CEquipmentBase:OnUnEquipped(player)

end;

function CEquipmentBase:Equip(player, bShouldEquip)
	if (bShouldEquip) then
		self:OnEquipped(player);
	else
		self:OnUnEquipped(player);
	end;
end;