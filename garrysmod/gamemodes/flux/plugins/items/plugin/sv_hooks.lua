--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flItems:InitPostEntity()
	item.Load()
end

function flItems:SaveData()
	item.SaveAll()
end

function flItems:ClientIncludedSchema(player)
	item.SendToPlayer(player)
end

function flItems:PlayerUseItemEntity(player, entity, itemTable)
	netstream.Start(player, "PlayerUseItemEntity", entity)
end

function flItems:PlayerTakeItem(player, itemTable, ...)
	if (IsValid(itemTable.entity)) then
		itemTable.entity:Remove()
		player:GiveItemByID(itemTable.instanceID)
		item.AsyncSaveEntities()
	end
end

function flItems:PlayerDropItem(player, instanceID, itemTable, ...)
	if (player:HasItemByID(instanceID)) then
		player:TakeItemByID(instanceID)

		local itemTable = item.FindInstanceByID(instanceID)
		local trace = player:GetEyeTraceNoCursor()
		local distance = trace.HitPos:Distance(player:GetPos())

		if (distance < 150) then
			item.Spawn(trace.HitPos + Vector(0, 0, 4), Angle(0, 0, 0), itemTable)
		else
			item.Spawn(player:EyePos() + trace.Normal * 20, Angle(0, 0, 0), itemTable)
		end

		item.AsyncSaveEntities()
	end
end

function flItems:PlayerUseItem(player, itemTable, ...)
	local trace

	if (IsValid(itemTable.entity)) then
		trace = player:GetEyeTraceNoCursor()

		if (!IsValid(trace.Entity)) then return end
		if (trace.Entity != itemTable.entity) then return end
	end

	if (player:HasItemByID(itemTable.instanceID) or trace != nil) then
		if (itemTable.OnUse) then
			local result = itemTable:OnUse(player)

			if (result == true) then
				return
			elseif (result == false) then
				return false
			end
		end

		if (trace != nil) then
			itemTable.entity:Remove()
		else
			player:TakeItemByID(itemTable.instanceID)
		end
	end
end

function flItems:OnItemGiven(player, itemTable, slot)
	hook.Run("PlayerInventoryUpdated", player)
end

function flItems:OnItemTaken(player, itemTable, slot)
	hook.Run("PlayerInventoryUpdated", player)
end

function flItems:PlayerInventoryUpdated(player)
	netstream.Start(player, "RefreshInventory")
end