function fl_inventory:PostCreateCharacter(player, char_id, char, char_data)
  char.items = ''
  char.inventory = {}

  plugin.call('AddDefaultItems', player, char, char.inventory)
end

function fl_inventory:OnActiveCharacterSet(player, character)
  local inv = {}
  local item_ids = string.Explode(',', character.item_ids or '')

  for k, v in ipairs(item_ids) do
    if !tonumber(v) then continue end

    local instance = item.FindInstanceByID(tonumber(v))
    if instance and instance.slot_id then
      local slot
      local cur_inv_type = instance.inventory_type or 'hotbar'
      local cur_inv = inv[cur_inv_type] or {}
      cur_inv.type = cur_inv_type
      local slot = cur_inv[instance.slot_id] or {}
      table.insert(slot, instance.instance_id)
      item.NetworkItem(player, instance.instance_id)
      cur_inv[instance.slot_id] = slot
      inv[cur_inv_type] = cur_inv
    end
  end

  character.real_inventory = inv
  player:set_nv('inventory', character.real_inventory)
end

function fl_inventory:SaveCharacterData(player, character)
  local item_ids = {}
  for inv_type, inv in pairs(character.real_inventory or {}) do
    if !istable(inv) then continue end
    for slot_id, slot in pairs(inv) do
      if !istable(slot) then continue end
      for k, v in ipairs(slot) do
        table.insert(item_ids, v)
      end
    end
  end
  character.item_ids = table.concat(item_ids, ',')
end

netstream.Hook('InventorySync', function(player, inventory)
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
