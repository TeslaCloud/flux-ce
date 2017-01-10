--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {};
PANEL.itemData = nil;
PANEL.itemCount = 0;
PANEL.instanceIDs = {};
PANEL.isHovered = false;

function PANEL:SetItem(instanceID)
	if (typeof(instanceID) == "table" and #instanceID > 1) then
		self:SetItemMulti(instanceID);
		return;
	end;

	if (typeof(instanceID) == "number") then
		self.itemData = item.FindInstanceByID(instanceID);
		self.itemCount = 1;
		self.instanceIDs = {instanceID}
		self:Rebuild();
	end;
end;

function PANEL:SetItemMulti(ids)
	local itemData = item.FindInstanceByID(ids[1]);

	if (!itemData.Stackable) then return; end;

	self.itemData = itemData;
	self.itemCount = #ids;
	self.instanceIDs = ids;
	self:Rebuild();
end;

function PANEL:Combine(panel2)
	for k, v in ipairs(panel2.instanceIDs) do
		if (#self.instanceIDs < self.itemData.MaxStack) then
			table.insert(self.instanceIDs, 1);
			table.remove(panel2.instanceIDs, 1);
		end;
	end;

	self.itemCount = #self.instanceIDs;
	self:Rebuild();

	panel2.itemCount = #panel2.instanceIDs;

	if (panel2.itemCount > 0) then
		panel2:Rebuild();
	else
		panel2:Reset();
	end;
end;

function PANEL:Reset()
	self.itemData = nil;
	self.itemCount = 0;
	self:Rebuild();
end;

function PANEL:Paint(w, h)
	if (self.isHovered and !self:IsHovered()) then
		self.isHovered = false;
	end;

	local drawColor = Color(255, 255, 255, 225);

	if (!self.isHovered) then
		if (!self.itemData) then
			drawColor = Color(190, 190, 190, 225);
		end;
	else
		drawColor = Color(220, 100, 100, 225);
	end;

	draw.RoundedBox(0, 0, 0, w, h, drawColor);

	if (self.itemCount >= 2) then
		DisableClipping(true);
			draw.SimpleText("x"..self.itemCount, "default", 50, 50, Color(255, 0, 0));
		DisableClipping(false);
	end;
end;

function PANEL:Rebuild()
	if (!self.itemData) then 
		if (IsValid(self.spawnIcon)) then
			self.spawnIcon:SetVisible(false);
			self.spawnIcon:Remove();
		end;

		return; 
	end;

	if (IsValid(self.spawnIcon)) then
		self.spawnIcon:SetVisible(false);
		self.spawnIcon:Remove();
	end;

	self.spawnIcon = vgui.Create("SpawnIcon", self);
	self.spawnIcon:SetPos(2, 2);
	self.spawnIcon:SetSize(60, 60);
	self.spawnIcon:SetModel(self.itemData.Model);
	self.spawnIcon:SetMouseInputEnabled(false);
end;

vgui.Register("reInventoryItem", PANEL, "DPanel");

local PANEL = {};
PANEL.inventory = {
	[5] = {1, 2}
};
PANEL.invSlots = 8;

function PANEL:SetInventory(inv)
	self.inventory = inv;
end;

function PANEL:SetSlots(num)
	self.invSlots = num;
end;

function PANEL:Rebuild()
	self.scroll = vgui.Create("DScrollPanel", self) //Create the Scroll panel
	self.scroll:SetSize(self:GetWide(), self:GetTall())
	self.scroll:SetPos(10, 30)

	self.list = vgui.Create("DIconLayout", self.scroll)
	self.list:SetSize(self:GetWide(), self:GetTall())
	self.list:SetPos(0, 0)
	self.list:SetSpaceY(4)
	self.list:SetSpaceX(4)

	for i = 1, self.invSlots do
		local invSlot = self.list:Add("reInventoryItem")
		invSlot:SetSize(64, 64)
		invSlot.slotNum = i;

		if (self.inventory[i]) then
			if (#self.inventory[i] <= 1) then
				invSlot:SetItem(self.inventory[i][1]);
			else
				invSlot:SetItemMulti(self.inventory[i]);
			end;
		end;

		invSlot:Receiver("rwItem", function(receiver, dropped, isDropped, menuIndex, mouseX, mouseY) 
			receiver.paintColor = Color(255, 0, 0)

			if (isDropped) then
				if (receiver.itemData) then
					if (receiver.itemData.uniqueID == dropped[1].itemData.uniqueID and
						receiver.slotNum != dropped[1].slotNum) then
						receiver:Combine(dropped[1]);
						return;
					else
						receiver.isHovered = false;
						return;
					end;
				end;

				local split = false;

				if (input.IsKeyDown(KEY_LCONTROL) and dropped[1].itemCount > 1) then
					split = {{}, {}};

					for i2 = 1, dropped[1].itemCount do
						if (i2 <= math.floor(dropped[1].itemCount / 2)) then
							table.insert(split[1], dropped[1].instanceIDs[i2]);
						else
							table.insert(split[2], dropped[1].instanceIDs[i2]);
						end
					end;
				end;

				if (!split) then
					receiver:SetItem(dropped[1].instanceIDs);
				else
					receiver:SetItemMulti(split[1]);
					dropped[1]:SetItemMulti(split[2]);
				end;

				receiver.isHovered = false;

				if (!split) then
					dropped[1]:Reset();
				else
					dropped[1]:Rebuild();
				end;
			else
				receiver.isHovered = true;
			end;
		end, {"Place"});

		invSlot:Droppable("rwItem");
	end
end;

vgui.Register("reInventory", PANEL, "reFrame");

concommand.Add("rwInvTest", function()
	local frame = vgui.Create("reInventory");
	frame:SetTitle("Inventory");
	frame:SetSize(560, 400);
	frame:SetPos(100, 100);
	frame:Rebuild();
	frame:MakePopup();
end);