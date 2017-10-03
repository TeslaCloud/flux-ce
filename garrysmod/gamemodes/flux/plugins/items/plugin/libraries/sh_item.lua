--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New "item"

-- Item Templates storage.
local stored = item.stored or {}
item.stored = stored

-- Actual items.
local instances = item.instances or {}
item.instances = instances

-- Instances table indexed by instance ID.
-- For quicker item lookups.
local sorted = item.sorted or {}
item.sorted = sorted

-- Items currently dropped and lying on the ground.
local entities = item.entities or {}
item.entities = entities

function item.GetAll()
	return stored
end

function item.GetInstances()
	return instances
end

function item.GetSorted()
	return sorted
end

function item.GetEntities()
	return entities
end

function item.Register(id, data)
	if (!data) then return end

	if (!isstring(data.Name) and isstring(data.PrintName)) then
		data.Name = data.PrintName
	end

	if (!isstring(id) and !isstring(data.Name)) then
		ErrorNoHalt("[Flux] Attempt to register an item without a valid ID!")
		debug.Trace()

		return
	end

	fl.DevPrint("Registering item: "..tostring(id))

	if (!id) then
		id = data.Name:MakeID()
	end

	data.uniqueID = id
	data.Name = data.Name or "Unknown Item"
	data.PrintName = data.PrintName or data.Name
	data.Description = data.Description or "This item has no description!"
	data.Weight = data.Weight or 1
	data.Stackable = data.Stackable or false
	data.MaxStack = data.MaxStack or 64
	data.Model = data.Model or "models/props_lab/cactus.mdl"
	data.Skin = data.Skin or 0
	data.Color = data.Color or nil
	data.Cost = data.Cost or 0
	data.SpecialColor = data.SpecialColor or nil
	data.Category = data.Category or "#Item_Category_Other"
	data.isBase = data.isBase or false
	data.instanceID = ITEM_TEMPLATE
	data.data = data.data or {}
	data.customButtons = data.customButtons or {}
	data.actionSounds = data.actionSounds or {}
	data.UseText = data.UseText
	data.TakeText = data.TakeText
	data.CancelText = data.CancelText
	data.UseIcon = data.UseIcon
	data.TakeIcon = data.TakeIcon
	data.CancelIcon = data.CancelIcon

	stored[id] = data
	instances[id] = instances[id] or {}
end

function item.ToSave(itemTable)
	if (!itemTable) then return end

	return {
		uniqueID = itemTable.uniqueID,
		Name = itemTable.Name,
		PrintName = itemTable.PrintName,
		Description = itemTable.Description,
		Weight = itemTable.Weight,
		Stackable = itemTable.Stackable,
		MaxStack = itemTable.MaxStack,
		Model = itemTable.Model,
		Skin = itemTable.Skin,
		Color = itemTable.Color,
		Cost = itemTable.Cost,
		SpecialColor = itemTable.SpecialColor,
		isBase = itemTable.isBase,
		instanceID = itemTable.instanceID,
		data = itemTable.data,
		actionSounds = itemTable.actionSounds,
		UseText = itemTable.UseText,
		TakeText = itemTable.TakeText,
		CancelText = itemTable.CancelText,
		UseIcon = itemTable.UseIcon,
		TakeIcon = itemTable.TakeIcon,
		CancelIcon = itemTable.CancelIcon
	}
end

-- Find item's template by it's ID.
function item.FindByID(uniqueID)
	for k, v in pairs(stored) do
		if (k == uniqueID or v.uniqueID == uniqueID) then
			return v
		end
	end
end

-- Find all instances of certain template ID.
function item.FindAllInstances(uniqueID)
	if (instances[uniqueID]) then
		return instances[uniqueID]
	end
end

-- Finds instance by it's ID.
function item.FindInstanceByID(instanceID)
	for k, v in pairs(instances) do
		if (istable(v)) then
			for k2, v2 in pairs(v) do
				if (k2 == instanceID) then
					return v2
				end
			end
		end
	end
end

-- Finds an item template that belongs to certain instance ID.
function item.FindByInstanceID(instanceID)
	if (!instanceID) then return end

	if (!sorted[instanceID]) then
		sorted[instanceID] = item.FindInstanceByID(instanceID)
	end

	return sorted[instanceID]
end

function item.Find(name)
	if (isnumber(name)) then
		return item.FindInstanceByID(name)
	end

	if (stored[id]) then
		return stored[id]
	end

	for k, v in pairs(stored) do
		if (v.uniqueID and v.Name and v.PrintName) then
			if (v.uniqueID == name or v.Name:find(name) or v.PrintName:find(name)) then
				return v
			end

			if (CLIENT) then
				if (fl.lang:TranslateText(v.PrintName):find(name)) then
					return v
				end
			end
		end
	end
end

function item.GenerateID()
	instances.count = instances.count or 0
	instances.count = instances.count + 1

	return instances.count
end

function item.New(uniqueID, tData, forcedID)
	local itemTable = item.FindByID(uniqueID)

	if (itemTable) then
		local itemID = forcedID or item.GenerateID()

		instances[uniqueID] = instances[uniqueID] or {}
		instances[uniqueID][itemID] = table.Copy(itemTable)

		if (istable(tData)) then
			table.Merge(instances[uniqueID][itemID], tData)
		end

		instances[uniqueID][itemID].instanceID = itemID

		if (SERVER) then
			item.AsyncSave()
			netstream.Start(nil, "ItemNewInstance", uniqueID, (tData or 1), itemID)
		end

		return instances[uniqueID][itemID]
	end
end

function item.Remove(instanceID)
	local itemTable = (istable(instanceID) and instanceID) or item.FindInstanceByID(instanceID)

	if (itemTable and item.IsInstance(itemTable)) then
		if (IsValid(itemTable.entity)) then
			itemTable.entity:Remove()
		end

		instances[itemTable.uniqueID][itemTable.instanceID] = nil

		if (SERVER) then
			item.AsyncSave()
		end

		fl.DevPrint("Removed item instance ID: "..itemTable.instanceID)
	end
end

function item.IsInstance(itemTable)
	if (!istable(itemTable)) then return end

	return (itemTable.instanceID or ITEM_TEMPLATE) > ITEM_INVALID
end

function item.CreateBase(strName)
	class(strName, nil, CItem)
end

pipeline.Register("item", function(uniqueID, fileName, pipe)
	ITEM = Item(uniqueID)

	util.Include(fileName)

	if (pipeline.IsAborted()) then ITEM = nil return end

	ITEM:Register() ITEM = nil
end)

function item.IncludeItems(directory)
	pipeline.IncludeDirectory("item", directory)
end

if (SERVER) then
	function item.Load()
		local loaded = data.LoadSchema("items/instances", {})

		if (loaded and table.Count(loaded) > 0) then
			-- Returns functions to instances table after loading.
			for uniqueID, instanceTable in pairs(loaded) do
				local itemTable = item.FindByID(uniqueID)

				if (itemTable) then
					for k, v in pairs(instanceTable) do
						local newItem = table.Copy(itemTable)

						table.Merge(newItem, v)

						loaded[uniqueID][k] = newItem
					end
				end
			end

			instances = loaded
			item.instances = loaded
		end

		local loaded = data.LoadSchema("items/entities", {})

		if (loaded and table.Count(loaded) > 0) then
			for uniqueID, instanceTable in pairs(loaded) do
				for k, v in pairs(instanceTable) do
					if (instances[uniqueID] and instances[uniqueID][k]) then
						item.Spawn(v.position, v.angles, instances[uniqueID][k])
					else
						loaded[uniqueID][k] = nil
					end
				end
			end

			entities = loaded
			item.entities = loaded
		end
	end

	function item.SaveInstances()
		local toSave = {}

		for k, v in pairs(instances) do
			if (k == "count") then
				toSave[k] = v
			else
				toSave[k] = {}
			end

			if (istable(v)) then
				for k2, v2 in pairs(v) do
					if (istable(v2)) then
						toSave[k][k2] = item.ToSave(v2)
					end
				end
			end
		end

		data.SaveSchema("items/instances", toSave)
	end

	function item.SaveEntities()
		local itemEnts = ents.FindByClass("fl_item")

		entities = {}

		for k, v in ipairs(itemEnts) do
			if (IsValid(v) and v.item) then
				entities[v.item.uniqueID] = entities[v.item.uniqueID] or {}

				entities[v.item.uniqueID][v.item.instanceID] = {
					position = v:GetPos(),
					angles = v:GetAngles()
				}
			end
		end

		data.SaveSchema("items/entities", entities)
	end

	function item.SaveAll()
		item.SaveInstances()
		item.SaveEntities()
	end

	function item.AsyncSave()
		local handle = coroutine.create(item.SaveAll)
		coroutine.resume(handle)
	end

	function item.AsyncSaveInstances()
		local handle = coroutine.create(item.SaveInstances)
		coroutine.resume(handle)
	end

	function item.AsyncSaveEntities()
		local handle = coroutine.create(item.SaveEntities)
		coroutine.resume(handle)
	end

	function item.NetworkItemData(player, itemTable)
		if (item.IsInstance(itemTable)) then
			netstream.Start(player, "ItemData", itemTable.uniqueID, itemTable.instanceID, itemTable.data)
		end
	end

	function item.NetworkItem(player, instanceID)
		netstream.Start(player, "NetworkItem", instanceID, item.ToSave(item.FindInstanceByID(instanceID)))
	end

	function item.NetworkEntityData(player, ent)
		if (IsValid(ent)) then
			netstream.Start(player, "ItemEntData", ent:EntIndex(), ent.item.uniqueID, ent.item.instanceID)
		end
	end

	-- A function to send info about items in the world.
	function item.SendToPlayer(player)
		local itemEnts = ents.FindByClass("fl_item")

		for k, v in ipairs(itemEnts) do
			if (v.item) then
				item.NetworkItem(player, v.item.instanceID)
			end
		end
	end

	function item.Spawn(position, angles, itemTable)
		if (!position or !istable(itemTable)) then
			ErrorNoHalt("[Flux:Item] No position or item table is not a table!\n")

			return
		end

		if (!item.IsInstance(itemTable)) then
			ErrorNoHalt("[Flux:Item] Cannot spawn non-instantiated item!\n")

			return
		end

		local ent = ents.Create("fl_item")

		ent:SetItem(itemTable)

		local mins, maxs = ent:GetCollisionBounds()

		ent:SetPos(position + Vector(0, 0, maxs.z))

		if (angles) then
			ent:SetAngles(angles)
		end

		ent:Spawn()

		itemTable:SetEntity(ent)
		item.NetworkItem(player, itemTable.instanceID)

		entities[itemTable.uniqueID] = entities[itemTable.uniqueID] or {}
		entities[itemTable.uniqueID][itemTable.instanceID] = entities[itemTable.uniqueID][itemTable.instanceID] or {}
		entities[itemTable.uniqueID][itemTable.instanceID] = {
			position = position,
			angles = angles
		}

		item.AsyncSaveEntities()

		return ent, itemTable
	end

	netstream.Hook("RequestItemData", function(player, entIndex)
		local ent = Entity(entIndex)

		if (IsValid(ent)) then
			item.NetworkEntityData(player, ent)
		end
	end)
else
	netstream.Hook("ItemData", function(uniqueID, instanceID, tData)
		if (istable(instances[uniqueID][instanceID])) then
			instances[uniqueID][instanceID].data = tData
		end
	end)

	netstream.Hook("NetworkItem", function(instanceID, itemTable)
		if (itemTable and stored[itemTable.uniqueID]) then
			local newTable = table.Copy(stored[itemTable.uniqueID])
			table.Merge(newTable, itemTable)

			instances[newTable.uniqueID][instanceID] = newTable

			print("Received instance ID "..tostring(newTable))
		else
			print("FAILED TO RECEIVE INSTANCE ID "..instanceID)
		end
	end)

	netstream.Hook("ItemEntData", function(entIndex, uniqueID, instanceID)
		local ent = Entity(entIndex)

		if (IsValid(Entity(entIndex))) then
			Entity(entIndex).item = instances[uniqueID][instanceID]
		end
	end)

	netstream.Hook("ItemNewInstance", function(uniqueID, tData, itemID)
		item.New(uniqueID, tData, itemID)
	end)
end