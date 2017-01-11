--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
	character.Load(player);
end);

netstream.Hook("PlayerDropItem", function(player, instanceID)
	if (player:HasItemByID(instanceID)) then
		player:TakeItemByID(instanceID);

		local itemTable = item.FindInstanceByID(instanceID);
		local trace = player:GetEyeTraceNoCursor();

		print("Spawning item...")

		item.Spawn(trace.HitPos, Angle(0, 0, 0), itemTable);
	end;
end);