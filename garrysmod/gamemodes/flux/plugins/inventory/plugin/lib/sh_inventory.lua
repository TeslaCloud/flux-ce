if !item then
  error("Attempt to use inventory system without Flux's items system.\n")
end

library.new "inventory"

do
  local player_meta = FindMetaTable("Player")

  -- Checks player inventory for garbage instance IDs and removes them if necessary.
  function player_meta:CheckInventory()
    local playerInv = self:GetInventory()

    for slot, ids in ipairs(playerInv) do
      for k, v in ipairs(ids) do
        local itemTable = item.FindInstanceByID(v)

        if !itemTable then
          playerInv[slot][k] = nil
        end
      end
    end

    self:SetInventory(playerInv)
  end

  if SERVER then
    function player_meta:AddItem(itemTable)
      if !itemTable then return -1 end

      local playerInv = self:GetInventory()
      local slots = self:GetCharacterData("invSlots", 8)

      for i = 1, slots do
        playerInv[i] = playerInv[i] or {}
        local ids = playerInv[i]

        -- Empty slot
        if #ids == 0 then
          table.insert(playerInv[i], itemTable.instance_id)
          self:SetInventory(playerInv)
          item.NetworkItem(self, itemTable.instance_id)

          return i
        end

        local slotTable = item.FindInstanceByID(ids[1])

        if itemTable.stackable and itemTable.id == slotTable.id then
          if #ids < itemTable.max_stack then
            table.insert(playerInv[i], itemTable.instance_id)
            self:SetInventory(playerInv)
            item.NetworkItem(self, itemTable.instance_id)

            return i
          end
        end
      end

      return false
    end

    function player_meta:GiveItem(id, instance_id, data)
      if !id then return end

      local itemTable

      if instance_id and instance_id > 0 then
        itemTable = item.FindInstanceByID(instance_id)
      else
        itemTable = item.New(id, data)
      end

      local slot = self:AddItem(itemTable)

      if slot and slot != -1 then
        hook.run("OnItemGiven", self, itemTable, slot)
      elseif slot == -1 then
        fl.dev_print("Failed to add item to player's inventory (itemTable is invalid)! "..tostring(itemTable))
      else
        fl.dev_print("Failed to add item to player's inventory (inv is full)! "..tostring(itemTable))
      end
    end

    function player_meta:GiveItemByID(instance_id)
      if !tonumber(instance_id) or tonumber(instance_id) <= 0 then return end

      local itemTable = item.FindInstanceByID(instance_id)

      if !itemTable then return end

      local slot = self:AddItem(itemTable)

      if slot and slot != -1 then
        hook.run("OnItemGiven", self, itemTable, slot)
      elseif slot == -1 then
        fl.dev_print("Failed to add item to player's inventory (itemTable is invalid)! "..tostring(itemTable))
      else
        fl.dev_print("Failed to add item to player's inventory (inv is full)! "..tostring(itemTable))
      end
    end

    function player_meta:TakeItemByID(instance_id)
      if !instance_id or instance_id < 1 then return end

      local playerInv = self:GetInventory()

      for slot, ids in ipairs(playerInv) do
        if table.HasValue(ids, instance_id) then
          table.RemoveByValue(playerInv[slot], instance_id)
          self:SetInventory(playerInv)

          hook.run("OnItemTaken", self, instance_id, slot)

          break
        end
      end
    end

    function player_meta:TakeItem(id, amount)
      amount = amount or 1
      local invInstances = self:FindInstances(id, amount)

      for i = 1, #invInstances do
        if amount > 0 then
          self:TakeItemByID(invInstances[i].instance_id)
          amount = amount - 1
        end
      end
    end
  end

  -- A function to find an amount of instances of an item in player's inventory.
  function player_meta:FindInstances(id, amount)
    amount = amount or 1
    local instances = item.FindAllInstances(id)
    local playerInv = self:GetInventory()
    local to_ret = {}

    for k, v in pairs(instances) do
      for slot, ids in ipairs(playerInv) do
        if table.HasValue(ids, k) then
          table.insert(to_ret, v)
          amount = amount - 1

          if amount <= 0 then
            return to_ret
          end
        end
      end
    end

    return to_ret
  end

  -- A function to find the first instance of an item in player's inventory.
  function player_meta:FindItem(id)
    return self:FindInstances(id)[1]
  end

  function player_meta:HasItemByID(instance_id)
    local playerInv = self:GetInventory()

    for slot, ids in ipairs(playerInv) do
      if table.HasValue(ids, instance_id) then
        return true
      end
    end

    return false
  end

  function player_meta:HasItem(id)
    local instances = self:FindInstances(id, 1)

    if instances[1] then
      return true
    end

    return false
  end

  function player_meta:HasItemEquipped(id)
    local instances = self:FindInstances(id, 1)
    local itemTable = instances[1]

    if itemTable and itemTable:IsEquipped() then
      return true
    end

    return false
  end
end
