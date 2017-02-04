--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Item"
ENT.Category = "Rework"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:EnableMotion(true)
			physObj:Wake()
		end
	end

	function ENT:SetItem(itemTable)
		if (!itemTable) then return false; end

		hook.Run("PreEntityItemSet", self, itemTable)

		self:SetModel(itemTable:GetModel())
		self:SetSkin(itemTable.Skin)
		self:SetColor(itemTable:GetColor())

		self.item = itemTable

		item.NetworkEntityData(nil, self)

		hook.Run("OnEntityItemSet", self, itemTable)
	end

	function ENT:Use(activator, caller, useType, value)
		if (IsValid(caller) and caller:IsPlayer()) then
			if (self.item) then
				hook.Run("PlayerUseItemEntity", caller, self, self.item)
			else
				rw.core:DevPrint("Player attempted to use an item entity without item object tied to it!")
			end
		end
	end
else
	function ENT:DrawTargetID(x, y, distance)
		if (distance > 370) then
			return
		end

		local text = "ERROR"
		local desc = "This item's data has failed to fetch. This is an error."
		local alpha = 255

		if (distance > 210) then
			local d = distance - 210
			alpha = math.Clamp(255 * (160 - d) / 160, 0, 255)
		end

		local col = Color(255, 255, 255, alpha)
		local col2 = Color(0, 0, 0, alpha)

		if (self.item) then
			if (hook.Run("PreDrawItemTargetID", self, self.item, x, y, alpha, distance) == false) then
				return
			end

			text = self.item.Name
			desc = self.item.Description
		else
			if (!self.dataRequested) then
				netstream.Start("RequestItemData", self:EntIndex())
				self.dataRequested = true
			end

			return
		end

		local width, height = util.GetTextSize(text, "tooltip_large")
		local width2, height2 = util.GetTextSize(desc, "tooltip_small")

		draw.SimpleTextOutlined(text, "tooltip_large", x - width * 0.5, y, col, nil, nil, 1, col2)
		y = y + 26

		draw.SimpleTextOutlined(desc, "tooltip_small", x - width2 * 0.5, y, col, nil, nil, 1, col2)
		y = y + 20

		hook.Run("PostDrawItemTargetID", self, self.item, x, y, alpha, distance)
	end
end