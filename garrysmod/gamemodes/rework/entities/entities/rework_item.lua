--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

AddCSLuaFile();

ENT.Type = "anim";
ENT.PrintName = "Item";
ENT.Category = "Rework"
ENT.Spawnable = false;
ENT.RenderGroup = RENDERGROUP_BOTH;

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS);
		self:PhysicsInit(SOLID_VPHYSICS);
		self:SetUseType(SIMPLE_USE);

		local physObj = self:GetPhysicsObject();

		if (IsValid(physObj)) then
			physObj:EnableMotion(true);
			physObj:Wake();
		end;
	end;

	function ENT:SetItem(itemTable)
		if (!itemTable) then return false; end;

		plugin.Call("PreEntityItemSet", self, itemTable);

		self:SetModel(itemTable:GetModel());
		self:SetColor(itemTable:GetColor())

		self.item = itemTable;

		item.NetworkEntityData(nil, self)

		plugin.Call("OnEntityItemSet", self, itemTable);
	end;

	function ENT:Use(activator, caller, useType, value)
		if (IsValid(caller) and caller:IsPlayer()) then
			if (self.item) then
				plugin.Call("PlayerUseItemEntity", caller, self, self.item);
			else
				rw.core:DevPrint("Player attempted to use an item entity without item object tied to it!")
			end;
		end;
	end;
else
	function ENT:DrawTargetID(x, y, distance)
		if (distance > 370) then
			return;
		end;

		local text = "derp";
		local desc = "derrrp";
		local alpha = 255;

		if (distance > 210) then
			local d = distance - 210;
			alpha = math.Clamp(255 * (160 - d) / 160, 0, 255);
		end

		local col = Color(255, 255, 255, alpha);

		if (self.item) then
			if (plugin.Call("PreDrawItemTargetID", self, self.item, x, y, alpha, distance) == false) then
				return;
			end;

			text = self.item:GetName();
			desc = self.item:GetDescription();
		else
			if (!self.dataRequested) then
				netstream.Start("RequestItemData", self:EntIndex());
				self.dataRequested = true;
			end;

			return;
		end;

		local width, height = util.GetTextSize("tooltip_large", text);

		draw.SimpleText(text, "tooltip_large", x - width * 0.5, y, col);
		y = y + 26;

		local width, height = util.GetTextSize("tooltip_small", desc);

		draw.SimpleText(desc, "tooltip_small", x - width * 0.5, y, col);
		y = y + 20;

		plugin.Call("PostDrawItemTargetID", self, self.item, x, y, alpha, distance);
	end;
end;