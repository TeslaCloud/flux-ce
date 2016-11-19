--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
	character.Load(player);
end);

netstream.Hook("PlayerUsedItemEntity", function(player, entity)
	if (IsValid(entity) and entity.item) then
		local instance = item.FindByInstanceID(entity.item.instanceID);

		if (instance.OnUse) then
			player:EmitSound("items/battery_pickup.wav");
			instance:OnUse(player);
		end;
	end;
end);