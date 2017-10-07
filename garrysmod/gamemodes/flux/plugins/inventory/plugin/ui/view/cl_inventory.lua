--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.itemData = nil
PANEL.itemCount = 0
PANEL.instanceIDs = {}
PANEL.isHovered = false

function PANEL:SetItem(instanceID)
	if (istable(instanceID)) then
		if (#instanceID > 1) then
			self:SetItemMulti(instanceID)

			return
		else
			return self:SetItem(instanceID[1])
		end
	end

	if (isnumber(instanceID)) then
		self.itemData = item.FindInstanceByID(instanceID)

		if (self.itemData) then
			self.itemCount = 1
			self.instanceIDs = {instanceID}
		end

		self:Rebuild()
	end
end

function PANEL:SetItemMulti(ids)
	local itemData = item.FindInstanceByID(ids[1])

	if (itemData and !itemData.Stackable) then return end

	self.itemData = itemData
	self.itemCount = #ids
	self.instanceIDs = ids
	self:Rebuild()
end

function PANEL:Combine(panel2)
	for i = 1, #panel2.instanceIDs do
		if (#self.instanceIDs < self.itemData.MaxStack) then
			table.insert(self.instanceIDs, panel2.instanceIDs[1])
			table.remove(panel2.instanceIDs, 1)
		end
	end

	self.itemCount = #self.instanceIDs
	self:Rebuild()

	panel2.itemCount = #panel2.instanceIDs

	if (panel2.itemCount > 0) then
		panel2:Rebuild()
	else
		panel2:Reset()
	end
end

function PANEL:Reset()
	self.itemData = nil
	self.itemCount = 0

	self:Rebuild()
	self:UnDraggable()
end

function PANEL:Paint(w, h)
	local drawColor = theme.GetColor("Background"):Lighten(70)

	if (self.isHovered and !self:IsHovered()) then
		self.isHovered = false
	end

	if (!self.isHovered) then
		if (!self.itemData) then
			drawColor = drawColor:Darken(25)
		else
			if (self.itemData.SpecialColor) then
				surface.SetDrawColor(self.itemData.SpecialColor)
				surface.DrawOutlinedRect(0, 0, w, h)
				surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
			end

			if (self:IsHovered()) then
				surface.SetDrawColor(Color(255, 255, 255))
				surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
			end
		end
	else
		local itemTable = self.itemData
		local curSlot = fl.inventoryDragSlot

		if (itemTable) then
			if (IsValid(curSlot) and curSlot.itemData != itemTable) then
				local slotData = curSlot.itemData

				if (slotData.uniqueID == itemTable.uniqueID and slotData.Stackable and curSlot.itemCount < slotData.MaxStack) then
					drawColor = Color(200, 200, 60)
				else
					drawColor = Color(200, 60, 60, 160)
				end
			else
				drawColor = drawColor:Lighten(30)
			end
		else
			drawColor = Color(60, 200, 60, 160)
		end
	end

	draw.RoundedBox(0, 0, 0, w, h, drawColor)

	if (self.itemCount >= 2) then
		DisableClipping(true)
			draw.SimpleText(self.itemCount, theme.GetFont("Text_Smallest"), 52, 50, Color(200, 200, 200))
		DisableClipping(false)
	end
end

function PANEL:Rebuild()
	if (!self.itemData) then
		if (IsValid(self.spawnIcon)) then
			self.spawnIcon:SafeRemove()
		end

		self:UnDraggable()

		return
	else
		self:Droppable("flItem")
	end

	if (IsValid(self.spawnIcon)) then
		self.spawnIcon:SetVisible(false)
		self.spawnIcon:Remove()
	end

	self.spawnIcon = vgui.Create("SpawnIcon", self)
	self.spawnIcon:SetPos(2, 2)
	self.spawnIcon:SetSize(60, 60)
	self.spawnIcon:SetModel(self.itemData.Model, self.itemData.Skin)
	self.spawnIcon:SetMouseInputEnabled(false)
end

function PANEL:OnMousePressed(...)
	self.mousePressed = CurTime()
	fl.inventoryDragSlot = self

	self.BaseClass.OnMousePressed(self, ...)
end

function PANEL:OnMouseReleased(...)
	if (self.itemData and self.mousePressed and self.mousePressed > (CurTime() - 0.15)) then
		fl.inventoryDragSlot = nil

		if (#self.instanceIDs > 1) then
			hook.Run("PlayerUseItemMenu", self.instanceIDs)
		else
			hook.Run("PlayerUseItemMenu", self.itemData)
		end
	end

	self.BaseClass.OnMouseReleased(self, ...)
end

vgui.Register("flInventoryItem", PANEL, "DPanel")

local PANEL = {}
PANEL.inventory = {}
PANEL.slots = {}
PANEL.invSlots = 8
PANEL.player = nil

function PANEL:SetInventory(inv)
	self.inventory = inv
end

function PANEL:SetPlayer(player)
	self.player = player
	self:SetInventory(player:GetInventory())

	self:Rebuild()
end

function PANEL:SetSlots(num)
	self.invSlots = num

	self:Rebuild()
end

function PANEL:SlotsToInventory()
	for k, v in ipairs(self.slots) do
		if (v.slotNum and v.itemData and #v.instanceIDs > 0) then
			self.inventory[v.slotNum] = v.instanceIDs
		else
			self.inventory[v.slotNum] = {}
		end
	end

	netstream.Start("InventorySync", self.inventory)
end

function PANEL:GetMenuSize()
	return font.Scale(560), font.Scale(self.invSlots * 0.125 * 68 + 36)
end

function PANEL:Rebuild()
	dragndrop.Clear()

	local multiplier = self.invSlots / 8

	self:SetSize(560, multiplier * 68 + 36)

	if (IsValid(self.player)) then
		self:SetInventory(self.player:GetInventory())
	end

	self.scroll = self.scroll or vgui.Create("DScrollPanel", self) //Create the Scroll panel
	self.scroll:SetSize(self:GetWide(), self:GetTall())
	self.scroll:SetPos(10, 32)

	if (IsValid(self.list)) then
		self.list:Clear()
	end

	self.list = self.list or vgui.Create("DIconLayout", self.scroll)
	self.list:SetSize(self:GetWide(), self:GetTall())
	self.list:SetPos(0, 0)
	self.list:SetSpaceY(4)
	self.list:SetSpaceX(4)

	for i = 1, self.invSlots do
		local invSlot = self.list:Add("flInventoryItem")
		invSlot:SetSize(64, 64)
		invSlot.slotNum = i

		if (self.inventory[i] and #self.inventory[i] > 0) then
			if (#self.inventory[i] > 1) then
				invSlot:SetItemMulti(self.inventory[i])
			else
				invSlot:SetItem(self.inventory[i][1])
			end
		end

		invSlot:Receiver("flItem", function(receiver, dropped, isDropped, menuIndex, mouseX, mouseY)
			if (isDropped) then
				fl.inventoryDragSlot = nil

				if (receiver.itemData) then
					if (receiver.itemData.uniqueID == dropped[1].itemData.uniqueID and
						receiver.slotNum != dropped[1].slotNum and receiver.itemData.Stackable) then
						receiver:Combine(dropped[1])
						self:SlotsToInventory()

						return
					else
						receiver.isHovered = false

						return
					end
				end

				local split = false

				if (input.IsKeyDown(KEY_LCONTROL) and dropped[1].itemCount > 1) then
					split = {{}, {}}

					for i2 = 1, dropped[1].itemCount do
						if (i2 <= math.floor(dropped[1].itemCount / 2)) then
							table.insert(split[1], dropped[1].instanceIDs[i2])
						else
							table.insert(split[2], dropped[1].instanceIDs[i2])
						end
					end
				end

				if (!split) then
					receiver:SetItem(dropped[1].instanceIDs)
				else
					receiver:SetItemMulti(split[1])
					dropped[1]:SetItemMulti(split[2])
				end

				receiver.isHovered = false

				if (!split) then
					dropped[1]:Reset()
				else
					dropped[1]:Rebuild()
				end

				self:SlotsToInventory()
			else
				receiver.isHovered = true
			end
		end, {"Place"})

		self.slots[i] = invSlot
	end

	self:GetParent():Receiver("flItem", function(receiver, dropped, isDropped, menuIndex, mouseX, mouseY)
		if (isDropped) then
			hook.Run("PlayerDropItem", dropped[1].itemData, dropped[1], mouseX, mouseY)
		end
	end, {})
end

vgui.Register("flInventory", PANEL, "flFrame")