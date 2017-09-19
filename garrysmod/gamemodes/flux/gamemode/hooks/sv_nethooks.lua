--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
	hook.Run("ClientIncludedSchema", player)
	hook.Run("PlayerInitialized", player)
end)

netstream.Hook("PlayerDropItem", function(player, instanceID, pos)
	hook.Run("PlayerDropItem", player, instanceID, pos)
end)

netstream.Hook("InventorySync", function(player, inventory)
	local newInventory = {}

	for slot, ids in ipairs(inventory) do
		newInventory[slot] = {}

		for k, v in ipairs(ids) do
			if (player:HasItemByID(v)) then
				table.insert(newInventory[slot], v)
			end
		end
	end

	player:SetInventory(newInventory)
end)

netstream.Hook("SoftUndo", function(player)
	fl.undo:DoPlayer(player)
end)

netstream.Hook("LocalPlayerCreated", function(player)
	netstream.Start(player, "SharedTables", fl.sharedTable)

	player:SendConfig()
	player:SyncNetVars()
end)

netstream.Hook("Flux::Player::Language", function(player, lang)
	player:SetNetVar("language", lang)
end)