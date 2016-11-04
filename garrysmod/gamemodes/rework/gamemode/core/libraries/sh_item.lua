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

-- Items currently dropped and lying on the ground.
local entities = item.entities or {};
item.entities = entities;

function item.Register(id, data)
	if (!id and !data.Name) then
		ErrorNoHalt("[Rework] Attempt to register an item without a valid ID!");
		debug.Trace();
		return;
	end;

	print("Registering item: "..id, data);

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
	data.Model = data.Model or "models/props_lab/cactus.mdl";
	data.Skin = data.Skin or 0;
	data.Color = data.Color or nil;
	data.instanceID = -1; -- -1 means no instance.
	data.data = data.data or {};

	stored[id] = data;
	instances[id] = instances[id] or {};
end;

function item.FindByID(uniqueID)
	for k, v in pairs(stored) do
		if (k == uniqueID or v.uniqueID == uniqueID) then
			return v;
		end;
	end;
end;

function item.GenerateID()
	instances.count = instances.count or 0;
	instances.count = instances.count + 1;

	return instances.count;
end;

function item.New(uniqueID, data, forcedID)
	local itemTable = item.FindByID(uniqueID);

	if (itemTable) then
		local itemID = forcedID or item.GenerateID();

		instances[uniqueID][itemID] = table.Copy(itemTable);

		if (typeof(data) == "table") then
			table.Merge(instances[uniqueID][itemID], data);
		end;

		instances[uniqueID][itemID].instanceID = itemID;

		if (SERVER) then
			item.SaveAll();
			netstream.Start(nil, "ItemNewInstance", uniqueID, data, itemID);
		end;

		return instances[uniqueID][itemID];
	end;
end;

function item.IsInstance(itemTable)
	if (typeof(itemTable) != "table") then return; end;

	return (itemTable.instanceID or -1) > 0;
end;

if (SERVER) then
	function item.Load()
		instances = data.LoadSchemaData("items/instances", {});

		-- Returns functions to instances table after loading.
		for uniqueID, instanceTable in pairs(instances) do
			local itemTable = item.FindByID(uniqueID);

			if (itemTable) then
				for k, v in pairs(instanceTable) do
					local newItem = table.Copy(itemTable);

					table.Merge(newItem, v);

					instances[uniqueID][k] = newItem;
				end;
			end;
		end;

		entities = data.LoadSchemaData("items/entities", {});

		for uniqueID, instances in pairs(entities) do
			for k, v in pairs(instances) do
				item.Spawn(v.position, v.angles, instances[uniqueID][k]);
			end
		end;
	end;

	function item.SaveAll()
		data.SaveSchemaData("items/instances", instances);
		data.SaveSchemaData("items/entities", entities);
	end;

	function item.NetworkItemData(player, itemTable)
		if (item.IsInstance(itemTable)) then
			netstream.Start(player, "ItemData", itemTable.uniqueID, itemTable.instanceID, itemTable.data);
		end;
	end;

	function item.NetworkEntityData(player, ent)
		if (IsValid(ent)) then
			netstream.Start(player, "ItemEntData", ent:EntIndex(), ent.item.uniqueID, ent.item.instanceID);
		end;
	end;

	function item.Spawn(position, angles, itemTable)
		if (!position or typeof(itemTable) != "table") then 
			print("No position or item table is not a table");
			return;
		end;

		if (!item.IsInstance(itemTable)) then
			ErrorNoHalt("Cannot spawn non-instantiated item!");
			return;
		end;

		local ent = ents.Create("rework_item");
		ent:SetItem(itemTable);
		ent:SetPos(position)
		ent:Spawn();

		itemTable:SetEntity(ent);
		item.NetworkItemData(nil, itemTable)

		entities[itemTable.uniqueID] = entities[itemTable.uniqueID] or {};
		entities[itemTable.uniqueID][itemTable.instanceID] = entities[itemTable.uniqueID][itemTable.instanceID] or {};
		entities[itemTable.uniqueID][itemTable.instanceID] = {
			position = position,
			angles = angles
		};

		return ent, itemTable;
	end;

	concommand.Add("rw_debug_spawnitem", function(player)
		local trace = player:GetEyeTraceNoCursor();

		print("Spawning test item...")

		item.Spawn(trace.HitPos, Angle(0, 0, 0), item.New("test_item"));
	end);
else
	netstream.Hook("ItemData", function(uniqueID, instanceID, data)
		print("ItemData", uniqueID, instanceID, data);
		instances[uniqueID][instanceID].data = data;
	end);

	netstream.Hook("ItemEntData", function(entIndex, uniqueID, instanceID)
		print("ItemEntData", entIndex, uniqueID, instanceID);
		local ent = Entity(entIndex);

		print(ent);

		if (IsValid(Entity(entIndex))) then
			print("set item clientside")
			Entity(entIndex).item = instances[uniqueID][instanceID];
		end;
	end);

	netstream.Hook("ItemNewInstance", function(uniqueID, data, itemID)
		item.New(uniqueID, data, itemID);
	end);
end;