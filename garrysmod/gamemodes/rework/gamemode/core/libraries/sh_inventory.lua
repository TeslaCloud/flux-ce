--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

if (!item) then
	rw.core:Include("sh_item.lua");
end;

library.New("inventory", _G);

do
	local playerMeta = FindMetaTable("Player");

	if (SERVER) then
		function playerMeta:AddItem(itemTable)
			local playerInv = self:GetInventory();
			local slots = self:GetCharacterData("invSlots", 8);

			for slot, ids in ipairs(playerInv) do
				if (slot > slots) then
					table.remove(playerInv, slots + 1);
					continue;
				end;

				-- Empty slot
				if (#ids == 0) then
					table.insert(playerInv[slot], itemTable.instanceID);
					self:SetInventory(playerInv);
					return slot;
				end;

				local slotTable = item.FindInstanceByID(ids[1]);

				if (itemTable.Stackable and itemTable.uniqueID == slotTable.uniqueID) then
					if (#ids < itemTable.MaxStack) then
						table.insert(playerInv[slot], itemTable.instanceID);
						self:SetInventory(playerInv);
						return slot;
					end;
				end;
			end;

			return false;
		end;

		function playerMeta:GiveItem(uniqueID, instanceID, data)
			if (!uniqueID) then return; end;

			local itemTable;

			if (instanceID and instanceID > 0) then
				itemTable = item.FindInstanceByID(instanceID);
			else
				itemTable = item.New(uniqueID, data);
			end;

			local slot = self:AddItem(itemTable);

			if (slot) then
				plugin.Call("OnItemGiven", self, itemTable, slot);
			else
				rw.core:DevPrint("Failed to add item to player's inventory (inv is full)! "..tostring(itemTable));
			end;
		end;

		-- A function to find all instances of an item in player's inventory.
		function playerMeta:FindInstances(uniqueID, amount)
			amount = amount or 1;
			local instances = item.FindAllInstances(uniqueID);
			local playerInv = self:GetInventory();
			local toReturn = {};

			for k, v in pairs(instances) do
				for slot, ids in ipairs(playerInv) do
					if (table.HasValue(ids, k)) then
						table.insert(toReturn, v);
						amount = amount - 1;

						if (amount <= 0) then
							return toReturn;
						end;
					end;
				end;
			end;

			return toReturn;
		end;

		-- A function to find the first instance of an item in player's inventory.
		function playerMeta:FindItem(uniqueID)
			return self:FindInstances(uniqueID)[1];
		end;

		function playerMeta:TakeItemByID(instanceID)
			if (!instanceID or instanceID < 1) then return; end;

			local playerInv = self:GetInventory();

			for slot, ids in ipairs(playerInv) do
				if (table.HasValue(ids, instanceID)) then
					table.RemoveByValue(playerInv[slot], instanceID);
					self:SetInventory(playerInv);
					plugin.Call("OnItemTaken", self, instanceID, slot);
					break;
				end
			end;
		end;

		function playerMeta:TakeItem(uniqueID, amount)
			amount = amount or 1;
			local invInstances = self:FindInstances(uniqueID, amount);

			for i = 1, #invInstances do
				if (amount > 0) then
					self:TakeItemByID(invInstances[i].instanceID);
					amount = amount - 1;
				end;
			end;
		end;
	end;
end;