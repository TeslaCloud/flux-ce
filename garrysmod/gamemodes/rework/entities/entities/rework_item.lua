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

		local physObj = self:GetPhysicsObject();

		if (IsValid(physObj)) then
			physObj:EnableMotion(true);
			physObj:Wake();
		end;
	end;

	function ENT:SetItem(itemTable)
		if (!itemTable) then return false; end;

		print("setting item!")

		self:SetModel(itemTable:GetModel());
		self:SetColor(itemTable:GetColor())

		self.item = itemTable;

		item.NetworkEntityData(nil, self)
	end;

	function ENT:Think()
		if (!self.dataSent) then
			item.NetworkEntityData(nil, self);
			self.dataSent = true;
		end
	end;
else
	function ENT:DrawTargetID(x, y)
		local text = "derp";
		local desc = "derrrp";
		local col = Color(255, 255, 255);

		if (self.item) then
			text = self.item:GetName();
			desc = self.item:GetDescription();
		else
			text = "This entity doesn't have any item tied to it. This is an error."
			desc = "ERROR";
			col = Color(255, 0, 0);
		end;

		local width, height = util.GetTextSize("tooltip_large", text);

		draw.SimpleText(text, "tooltip_large", x - width * 0.5, y, col);

		local width, height = util.GetTextSize("tooltip_small", desc);

		draw.SimpleText(desc, "tooltip_small", x - width * 0.5, y + 26, col);
	end;
end;