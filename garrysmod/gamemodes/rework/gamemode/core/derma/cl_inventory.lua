--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local PANEL = {};
PANEL.inventory = {};

function PANEL:SetInventory(inv)
	self.inventory = inv;
end;

function PANEL:Rebuild()
	self.scroll = vgui.Create("DScrollPanel", self) //Create the Scroll panel
	self.scroll:SetSize(355, 200)
	self.scroll:SetPos(10, 30)

	self.list = vgui.Create("DIconLayout", self.scroll)
	self.list:SetSize(340, 200)
	self.list:SetPos(0, 0)
	self.list:SetSpaceY(5) //Sets the space in between the panels on the X Axis by 5
	self.list:SetSpaceX(5) //Sets the space in between the panels on the Y Axis by 5

	for i = 1, 20 do //Make a loop to create a bunch of panels inside of the DIconLayout
		local ListItem = self.list:Add("DDragBase") //Add DPanel to the DIconLayout
		ListItem:SetSize(40, 40) //Set the size of it
		ListItem.Paint = function(li, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(10 * i, 10 * i, 10 * i));
		end;
		//You don't need to set the position, that is done automatically.
	end
end;

vgui.Register("reInventory", PANEL, "reFrame");

concommand.Add("rwInvTest", function()
	local frame = vgui.Create("reInventory");
	frame:SetSize(600, 400);
	frame:SetPos(100, 100);
	frame:Rebuild();
	frame:MakePopup();
end);