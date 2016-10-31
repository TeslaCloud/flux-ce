--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("item", _G);

-- Item Templates storage.
local stored = item.stored or {};
item.stored = stored;

-- Actual items.
local instances = item.instances or {};
item.instances = instances;

function item.Register(id, data)
	if (!id and !data.Name) then
		ErrorNoHalt("[Rework] Attempt to register an item without a valid ID!");
		debug.Trace();
		return;
	end;

	if (!id) then
		id = data.Name:MakeID();
	end;

	data.uniqueID = id;
	data.Name = data.Name or "Unknown Item";
	data.PrintName = data.PrintName or data.Name;
	data.Description = data.Description or "This item has no description!";
	data.Weight = data.Weight or 1;
	data.IsStackable = data.IsStackable or false;
	data.MaxStack = data.MaxStack or 64;

	stored[id] = data;
end;