--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

if (!item) then
  error("Attempt to use inventory system without Flux's items system.\n")
end

library.New "inventory"

do
  local player_meta = FindMetaTable("Player")

  -- Checks player inventory for garbage instance IDs and removes them if necessary.
  function player_meta:CheckInventory()
    local playerInv = self:GetInventory()

    for slot, ids in ipairs(playerInv) do
      for k, v in ipairs(ids) do
        local itemTable = item.FindInstanceByID(v)

        if (!itemTable) then
          playerInv[slot][k] = nil
        end
      end
    end

    self:SetInventory(playerInv)
  end

  if (SERVER) then
    function player_meta:AddItem(itemTable)
      if (!itemTable) then return -1 end

      local playerInv = self:GetInventory()
      local slots = self:GetCharacterData("invSlots", 8)

      for i = 1, slots do
        playerInv[i] = playerInv[i] or {}
        local ids = playerInv[i]

        -- Empty slot
        if (#ids == 0) then
          table.insert(playerInv[i], itemTable.instanceID)
          self:SetInventory(playerInv)
          item.NetworkItem(self, itemTable.instanceID)

          return i
        end

        local slotTable = item.FindInstanceByID(ids[1])

        if (itemTable.Stackable and itemTable.id == slotTable.id) then
          if (#ids < itemTable.MaxStack) then
            table.insert(playerInv[i], itemTable.instanceID)
            self:SetInventory(playerInv)
            item.NetworkItem(self, itemTable.instanceID)

            return i
          end
        end
      end

      return false
    end

    function player_meta:GiveItem(uniqueID, instanceID, data)
      if (!uniqueID) then return end

      local itemTable

      if (instanceID and instanceID > 0) then
        itemTable = item.FindInstanceByID(instanceID)
      else
        itemTable = item.New(uniqueID, data)
      end

      local slot = self:AddItem(itemTable)

      if (slot and slot != -1) then
        hook.Run("OnItemGiven", self, itemTable, slot)
      elseif (slot == -1) then
        fl.DevPrint("Failed to add item to player's inventory (itemTable is invalid)! "..tostring(itemTable))
      else
        fl.DevPrint("Failed to add item to player's inventory (inv is full)! "..tostring(itemTable))
      end
    end

    function player_meta:GiveItemByID(instanceID)
      if (!tonumber(instanceID) or tonumber(instanceID) <= 0) then return end

      local itemTable = item.FindInstanceByID(instanceID)

      if (!itemTable) then return end

      local slot = self:AddItem(itemTable)

      if (slot and slot != -1) then
        hook.Run("OnItemGiven", self, itemTable, slot)
      elseif (slot == -1) then
        fl.DevPrint("Failed to add item to player's inventory (itemTable is invalid)! "..tostring(itemTable))
      else
        fl.DevPrint("Failed to add item to player's inventory (inv is full)! "..tostring(itemTable))
      end
    end

    function player_meta:TakeItemByID(instanceID)
      if (!instanceID or instanceID < 1) then return end

      local playerInv = self:GetInventory()

      for slot, ids in ipairs(playerInv) do
        if (table.HasValue(ids, instanceID)) then
          table.RemoveByValue(playerInv[slot], instanceID)
          self:SetInventory(playerInv)

          hook.Run("OnItemTaken", self, instanceID, slot)

          break
        end
      end
    end

    function player_meta:TakeItem(uniqueID, amount)
      amount = amount or 1
      local invInstances = self:FindInstances(uniqueID, amount)

      for i = 1, #invInstances do
        if (amount > 0) then
          self:TakeItemByID(invInstances[i].instanceID)
          amount = amount - 1
        end
      end
    end
  end

  -- A function to find an amount of instances of an item in player's inventory.
  function player_meta:FindInstances(uniqueID, amount)
    amount = amount or 1
    local instances = item.FindAllInstances(uniqueID)
    local playerInv = self:GetInventory()
    local toReturn = {}

    for k, v in pairs(instances) do
      for slot, ids in ipairs(playerInv) do
        if (table.HasValue(ids, k)) then
          table.insert(toReturn, v)
          amount = amount - 1

          if (amount <= 0) then
            return toReturn
          end
        end
      end
    end

    return toReturn
  end

  -- A function to find the first instance of an item in player's inventory.
  function player_meta:FindItem(uniqueID)
    return self:FindInstances(uniqueID)[1]
  end

  function player_meta:HasItemByID(instanceID)
    local playerInv = self:GetInventory()

    for slot, ids in ipairs(playerInv) do
      if (table.HasValue(ids, instanceID)) then
        return true
      end
    end

    return false
  end

  function player_meta:HasItem(uniqueID)
    local instances = self:FindInstances(uniqueID, 1)

    if (instances[1]) then
      return true
    end

    return false
  end

  function player_meta:HasItemEquipped(uniqueID)
    local instances = self:FindInstances(uniqueID, 1)
    local itemTable = instances[1]

    if (itemTable and itemTable:IsEquipped()) then
      return true
    end

    return false
  end
end
