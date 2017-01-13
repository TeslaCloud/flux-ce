--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

Class("CConsumablesBase", CItem);

function CConsumablesBase:CConsumablesBase(id, base)
	self.useText = "Consume";
end;

function item.CreateConsumable(...)
	return CConsumablesBase(...);
end;