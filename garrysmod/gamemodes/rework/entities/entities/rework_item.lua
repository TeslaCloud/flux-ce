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
		self:SetModel("models/props_lab/cactus.mdl");
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

		self:SetModel(itemTable.model);
	end;
end;