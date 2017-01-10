--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
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