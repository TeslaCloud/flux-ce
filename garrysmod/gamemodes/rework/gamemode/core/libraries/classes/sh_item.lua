--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

Class "CItem";

function CItem:CItem(uniqueID)
	self.uniqueID = uniqueID;
	self.data = self.data or {};
end;

function CItem:GetName()
	return self.PrintName or self.Name;
end;

CItem.Name = CItem.GetName;

function CItem:GetRealName()
	return self.Name or "Unknown Item";
end;

function CItem:GetDescription()
	return self.Description or "This item has no description!";
end;

function CItem:GetWeight()
	return self.Weight or 1;
end;

function CItem:IsStackable()
	return self.Stackable;
end;

function CItem:GetMaxStack()
	return self.MaxStack or 64;
end;

function CItem:GetModel()
	return self.Model or "models/props_lab/cactus.mdl";
end;

function CItem:GetSkin()
	return self.Skin or 0;
end;

function CItem:GetColor()
	return self.Color or Color(255, 255, 255);
end;

-- Returns:
-- true = drop normally
-- false = prevents item appearing and doesn't remove it from inventory.
function CItem:OnDrop(player)
	return true;
end;

-- Returns:
-- true = removes item from the inventory as soon as it's used.
-- false = prevents item from being removed upon use.
function CItem:OnUse(player)
	return true;
end;

if (SERVER) then
	function CItem:SetData(id, value)
		if (!id) then return; end;

		self.data[id] = value;

		item.NetworkItemData(self);
	end;
end;

function CItem:GetData(id, default)
	if (!id) then return; end;

end;

function CItem:SetEntity(ent)
	self.entity = ent;
end;

function CItem:Register()
	return item.Register(self.uniqueID, self);
end;

-- Fancy output if you do print(itemTable).
function CItem:__tostring()
	return "Item ["..self.instanceID.."]["..self:GetName().."]";
end;

Item = CItem;