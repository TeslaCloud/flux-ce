--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local ITEM = Item("test_item");

	ITEM.Name = "Test Item";
	ITEM.Description = "An item that has a single purpose: system testing. Great, yeah."
	ITEM.Model = "models/props_junk/metal_paintcan001a.mdl";

	function ITEM:OnUse(player)
		print("player used item!");
	end;

ITEM:Register();