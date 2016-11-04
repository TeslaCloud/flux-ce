--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

if (!item) then
	rw.core:Include("sh_item.lua");
end;

library.New("inventory", _G);

do
	local playerMeta = FindMetaTable("Player");

	if (SERVER) then
		function playerMeta:GiveItem(uniqueID, instanceID, data)
			if (!uniqueID) then return; end;

			local itemTable;

			if (instanceID and instanceID > 0) then
				itemTable = item.FindInstanceByID(instanceID);
			else
				itemTable = item.New(uniqueID, data);
			end;

			local playerInv = self:GetInventory();

			if (!table.HasValue(playerInv, itemTable.instanceID)) then
				table.insert(playerInv, itemTable.instanceID);
				self:SetInventory(playerInv);
				plugin.Call("OnItemGiven", self, itemTable);
			end;
		end;

		-- A function to find the first instance of uniqueID in player's inventory.
		function playerMeta:FindInstances(uniqueID, amount)
			amount = amount or 1;
			local instances = item.FindAllInstances(uniqueID);
			local playerInv = self:GetInventory();

			local toReturn = {};

			for k, v in pairs(instances) do
				if (table.HasValue(playerInv, k)) then
					table.insert(toReturn, v);
					amount = amount - 1;

					if (amount <= 0) then
						return toReturn;
					end;
				end;
			end;

			return toReturn;
		end;

		function playerMeta:FindItem(uniqueID)
			local invInstances = self:FindInstances(uniqueID);

			return invInstances[1];
		end;

		function playerMeta:TakeItemByID(instanceID)
			if (!instanceID or instanceID < 1) then return; end;

			local playerInv = self:GetInventory();

			if (table.HasValue(playerInv, instanceID)) then
				table.RemoveByValue(playerInv, instanceID);
				self:SetInventory(playerInv);
				plugin.Call("OnItemTaken", self, instanceID);
			end;
		end;

		function playerMeta:TakeItem(uniqueID, amount)
			amount = amount or 1;
			local invInstances = self:FindInstances(uniqueID, amount);
			local playerInv = self:GetInventory();

			for k, v in ipairs(invInstances) do
				table.RemoveByValue(playerInv, v);
				plugin.Call("OnItemTaken", self, v);
			end;

			self:SetInventory(playerInv);
		end;
	end;
end;