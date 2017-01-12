--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
	character.Load(player);
	item.SendToPlayer(player);
end);

netstream.Hook("PlayerDropItem", function(player, instanceID)
	if (player:HasItemByID(instanceID)) then
		player:TakeItemByID(instanceID);

		local itemTable = item.FindInstanceByID(instanceID);
		local trace = player:GetEyeTraceNoCursor();
		local distance = trace.HitPos:Distance(player:GetPos());

		print("Spawning item...")

		if (distance < 240) then
			item.Spawn(trace.HitPos + Vector(0, 0, 4), Angle(0, 0, 0), itemTable);
		else
			item.Spawn(player:EyePos() + trace.Normal * 20, Angle(0, 0, 0), itemTable);
		end;
	end;
end);

netstream.Hook("InventorySync", function(player, inventory)
	local newInventory = {};

	for slot, ids in ipairs(inventory) do
		newInventory[slot] = {};

		for k, v in ipairs(ids) do
			if (player:HasItemByID(v)) then
				table.insert(newInventory[slot], v);
			end;
		end;
	end;

	player:SetInventory(newInventory);
end);