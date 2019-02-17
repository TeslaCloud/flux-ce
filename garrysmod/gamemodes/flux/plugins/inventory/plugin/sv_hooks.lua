function Inventory:PostCreateCharacter(player, char_id, char, char_data)
  plugin.call('AddDefaultItems', player, char, char.inventory)
end

function Inventory:OnActiveCharacterSet(player, character)
  local inv = {}
  local item_ids = (character.item_ids or ''):split(';')

  for k, v in ipairs(item_ids) do
    v = v:split(',')

    if !tonumber(v) then continue end

    local instance = item.find_instance_by_id(tonumber(v))

    if instance and instance.slot_id then
      local slot
      local cur_inv_type = instance.inventory_type or 'hotbar'
      local cur_inv = inv[cur_inv_type] or {}

      cur_inv.type = cur_inv_type

      local slot = cur_inv[instance.slot_id] or {}

      table.insert(slot, instance.instance_id)

      item.network_item(player, instance.instance_id)

      cur_inv[instance.slot_id] = slot
      inv[cur_inv_type] = cur_inv
    end
  end

  character.real_inventory = inv
  player:set_nv('inventory', character.real_inventory)
end

function Inventory:SaveCharacterData(player, char)
  local item_ids = {}

  for inv_type, inv in pairs(char.real_inventory or {}) do
    if !istable(inv) then continue end

    for slot_id, slot in pairs(inv) do
      if !istable(slot) then continue end

      for k, v in ipairs(slot) do
        table.insert(item_ids, table.concat(v, ','))
      end
    end
  end

  char.item_ids = table.concat(item_ids, ',')
end

cable.receive('fl_inventory_sync', function(player, inventory)
  local inv_type = inventory.type
  local new_inventory = {}

  for k, v in ipairs(inventory) do
    new_inventory[k] = new_inventory[k] or {}

    for k1, v1 in ipairs(v) do
      new_inventory[k][k1] = new_inventory[k][k1] or {}

      for k2, v2 in ipairs(v1) do
        if player:has_item_by_id(v2) then
          local item_table = item.find_instance_by_id(v2)
          item_table.inventory_type = inv_type

          table.insert(new_inventory[k][k1], v2)
        end
      end
    end
  end

  player:set_inventory(new_inventory, inv_type)
end)
