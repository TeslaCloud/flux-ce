function fl_inventory:PostCreateCharacter(player, char_id, character)
  character.items = ''
  character.inventory = {}

  plugin.call('AddDefaultItems', player, character, character.inventory)
end

function fl_inventory:OnActiveCharacterSet(player, character)
  local inv = {}
  local item_ids = string.Explode(',', character.item_ids or '')

  for k, v in ipairs(item_ids) do
    if !tonumber(v) then continue end

    local instance = item.FindInstanceByID(tonumber(v))
    if instance and instance.slot_id then
      local slot = inv[instance.slot_id] or {}
      table.insert(slot, instance.instance_id)
      item.NetworkItem(player, instance.instance_id)
      inv[instance.slot_id] = slot
    end
  end

  character.real_inventory = inv
  player:set_nv('inventory', character.real_inventory)
end

function fl_inventory:SaveCharacterData(player, character)
  local item_ids = {}
  for slot_id, slot in pairs(character.real_inventory or {}) do
    for k, v in ipairs(slot) do
      table.insert(item_ids, v)
    end
  end
  character.item_ids = table.concat(item_ids, ',')
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
