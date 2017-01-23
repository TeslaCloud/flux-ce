--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

Class "CItem";

function CItem:CItem(uniqueID, baseID)
	self.uniqueID = uniqueID;
	self.Base = baseID;
	self.data = self.data or {};
	self.customButtons = {};
	self.actionSounds = {
		["OnUse"] = "items/battery_pickup.wav"
	};
end;

function CItem:GetName()
	return self.PrintName or self.Name;
end;

CItem.Name = CItem.GetName;

function CItem:GetRealName()
	return self.Name or "Unknown Item";
end;

function CItem:GetDescription()
	return self.Description or "This item has no description!";
end;

function CItem:GetWeight()
	return self.Weight or 1;
end;

function CItem:IsStackable()
	return self.Stackable;
end;

function CItem:GetMaxStack()
	return self.MaxStack or 64;
end;

function CItem:GetModel()
	return self.Model or "models/props_lab/cactus.mdl";
end;

function CItem:GetSkin()
	return self.Skin or 0;
end;

function CItem:GetColor()
	return self.Color or Color(255, 255, 255);
end;

function CItem:AddButton(name, data)
	self.customButtons[name] = data;
end;

function CItem:SetActionSound(act, sound)
	self.actionSounds[act] = sound;
end;

-- Returns:
-- nothing/nil = drop like normal
-- false = prevents item appearing and doesn't remove it from inventory.
function CItem:OnDrop(player) end;

-- Returns:
-- nothing/nil = removes item from the inventory as soon as it's used.
-- false = prevents item from being used at all.
-- true = prevents item from being removed upon use.
function CItem:OnUse(player) end;

if (SERVER) then
	function CItem:SetData(id, value)
		if (!id) then return; end;

		self.data[id] = value;

		item.NetworkItemData(self);
	end;

	function CItem:DoMenuAction(act, player, ...)
		if (act == "OnTake") then
			if (hook.Run("PlayerTakeItem", player, self, ...) != nil) then return; end;
		end;

		if (act == "OnUse") then
			if (hook.Run("PlayerUseItem", player, self, ...) != nil) then return; end;
		end;

		if (act == "OnDrop") then
			if (hook.Run("PlayerDropItem", player, self.instanceID, self, ...) != nil) then return; end;
		end;

		if (self[act]) then
			if (act != "OnTake" and act != "OnUse" and act != "OnTake") then
				local succ, result = pcall(self[act], self, player, ...);

				if (!succ) then
					ErrorNoHalt("Item callback has failed to run! "..tostring(result).."\n");
					return;
				end;
			end;

			if (self.actionSounds[act]) then
				player:EmitSound(self.actionSounds[act]);
			end;
		end;

		if (act == "OnTake") then
			if (hook.Run("PlayerTakenItem", player, self, ...) != nil) then return; end;
		end;

		if (act == "OnUse") then
			if (hook.Run("PlayerUsedItem", player, self, ...) != nil) then return; end;

			item.Remove(self);
		end;

		if (act == "OnDrop") then
			if (hook.Run("PlayerDroppedItem", player, self.instanceID, self, ...) != nil) then return; end;
		end;
	end;

	netstream.Hook("ItemMenuAction", function(player, instanceID, action, ...)
		local itemTable = item.FindInstanceByID(instanceID);

		if (!itemTable) then return; end;
		if (hook.Run("PlayerCanUseItem", player, itemTable, action, ...) == false) then return; end;

		itemTable:DoMenuAction(action, player, ...);
	end);
else
	function CItem:DoMenuAction(act, ...)
		netstream.Start("ItemMenuAction", self.instanceID, act, ...);
	end;
end;

function CItem:GetData(id, default)
	if (!id) then return; end;

	return self.data[id] or default;
end;

function CItem:SetEntity(ent)
	self.entity = ent;
end;

function CItem:Register()
	return item.Register(self.uniqueID, self);
end;

-- Fancy output if you do print(itemTable).
function CItem:__tostring()
	return "Item ["..self.instanceID.."]["..self:GetName().."]";
end;

Item = CItem;