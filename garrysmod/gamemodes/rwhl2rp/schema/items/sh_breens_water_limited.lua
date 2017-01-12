--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local ITEM = Item("breens_water_limited");

	ITEM.Name = "Breen's Water: Limited Edition";
	ITEM.PrintName = "Breen's Water: Limited Edition";
	ITEM.Description = "A yellow can filled with limited-tier flavored water."
	ITEM.Model = "models/props_junk/popcan01a.mdl";
	ITEM.Skin = 2;
	ITEM.Weight = 0.35;
	ITEM.Stackable = true;
	ITEM.MaxStack = 8;
	ITEM.SpecialColor = Color(100, 255, 100);
	ITEM.useText = "Drink";

	function ITEM:OnUse(player)
		print("Player just drank some limited breen's water. #tastybrainwash");
	end;

ITEM:Register();