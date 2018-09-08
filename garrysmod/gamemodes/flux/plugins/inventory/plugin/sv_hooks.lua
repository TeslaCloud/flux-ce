function fl_inventory:PostCharacterLoaded(player, character)
  player:CheckInventory()

  for slot, ids in ipairs(player:GetInventory()) do
    for k, v in ipairs(ids) do
      item.NetworkItem(player, v)
    end
  end
end

netstream.Hook("InventorySync", function(player, inventory)
  local newInventory = {}

  for slot, ids in ipairs(inventory) do
    newInventory[slot] = {}

    for k, v in ipairs(ids) do
      if player:HasItemByID(v) then
        table.insert(newInventory[slot], v)
      end
    end
  end

  player:SetInventory(newInventory)
end)
