function Inventory:PostCreateCharacter(player, char_id, char, char_data)
  plugin.call('AddDefaultItems', player, char, char.inventory)
end

function Inventory:OnActiveCharacterSet(player, character)
  local inv = {}
  local item_ids = (character.item_ids or ''):split(',')

  for k, v in ipairs(item_ids) do
    if !tonumber(v) then continue end

    local instance = item.find_instance_by_id(tonumber(v))

    if instance and instance.slot_id then
      local cur_inv_type = instance.inventory_type or 'hotbar'
      local cur_inv = inv[cur_inv_type] or {}
      local y, x = unpack(instance.slot_id)

      cur_inv.type = cur_inv_type
      cur_inv.width, cur_inv.height = player:get_inventory_size(cur_inv_type)

      cur_inv[y] = cur_inv[y] or {}

      local slot = cur_inv[y][x] or {}

      table.insert(slot, instance.instance_id)

      item.network_item(player, instance.instance_id)

      cur_inv[y][x] = slot
      inv[cur_inv_type] = cur_inv
    end
  end

  character.real_inventory = inv
  player:set_nv('inventory', character.real_inventory)
end

function Inventory:SaveCharacterData(player, char)
  char.item_ids = table.concat(player:get_items(), ',')
end

function Inventory:OnItemInventoryChanged(player, item_table, new_inv, old_inv)
  if item_table.on_inventory_changed then
    item_table:on_inventory_changed(player, new_inv, old_inv)
  end
end

function Inventory:CanItemMove(player, item_table, inv_type, x, y)
  if !item_table or !x or !y or !inv_type then
    return false
  end

  if item_table.can_move then
    return item_table:can_move(player, inv_type, x, y)
  end
end

function Inventory:CanItemTransfer(player, item_table, inv_type, x, y)
  if !item_table or !inv_type then
    return false
  end

  if item_table.inventory_type == inv_type then
    return true
  end

  if inv_type == 'equipment' and !item_table.equip_slot then
    return false
  end

  if item_table.can_transfer then
    return item_table:can_transfer(player, inv_type, x, y)
  end
end

function Inventory:CanItemStack(player, item_table, inv_type, x, y)
  if !item_table or !x or !y or !inv_type then
    return false
  end

  local ids = player:get_slot(x, y, inv_type)

  if #ids == 0 then
    return true
  end

  local slot_table = item.find_instance_by_id(ids[1])

  if item_table.id != slot_table.id or #ids >= item_table.max_stack then
    return false
  end

  if item_table.can_stack then
    return item_table:can_stack(player, inv_type, x, y)
  end
end

function Inventory:OnItemMove(player, instance_ids, inv_type, x, y)
  local ply_inv = player:get_inventory(inv_type)

  for k, v in pairs(instance_ids) do
    local item_table = item.find_instance_by_id(v)

    if hook.run('CanItemTransfer', player, item_table, inv_type, x, y) == false or
       hook.run('CanItemMove', player, item_table, inv_type, x, y) == false or 
       hook.run('CanItemStack', player, item_table, inv_type, x, y) == false then
      return
    end

    local old_y, old_x = unpack(item_table.slot_id)
    local old_inv_type = item_table.inventory_type

    table.insert(ply_inv[y][x], v)

    item_table.slot_id = { y, x }

    if old_inv_type != inv_type then
      local old_inv = player:get_inventory(old_inv_type)

      table.remove_by_value(old_inv[old_y][old_x], v)
      player:set_inventory(old_inv, old_inv_type)

      hook.run('OnItemInventoryChanged', player, item_table, inv_type, old_inv_type)

      item_table.inventory_type = inv_type
    else
      table.remove_by_value(ply_inv[old_y][old_x], v)
    end

    item.network_item(player, v)
  end

  player:set_inventory(ply_inv, inv_type)

  Cable.send(player, 'fl_inventory_refresh', inv_type, old_inv_type)
end

Cable.receive('fl_inventory_sync', function(player, inventory)
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
          item_table.slot_id = { k1, k }

          table.insert(new_inventory[k][k1], v2)
        end
      end
    end
  end

  new_inventory.width, new_inventory.height = inventory.width, inventory.height
  new_inventory.type = inv_type

  player:set_inventory(new_inventory, inv_type)
end)

Cable.receive('fl_item_move', function(player, instance_ids, inv_type, x, y)
  hook.run('OnItemMove', player, instance_ids, inv_type, x, y)
end)
