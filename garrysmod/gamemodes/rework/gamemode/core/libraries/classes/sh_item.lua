--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

Class "CItem";

function CItem:CItem(uniqueID)
	self.uniqueID = uniqueID;
end;

function CItem:GetName()
	return self.PrintName or self.Name;
end;

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
	return self.IsStackable;
end;

function CItem:GetMaxStack()
	return self.MaxStack or 64;
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

function CItem:Register()
	return item.Register(self.uniqueID, self);
end;