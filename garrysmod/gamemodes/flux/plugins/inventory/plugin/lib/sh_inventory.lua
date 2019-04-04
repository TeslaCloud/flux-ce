if !Inventory then
  PLUGIN:set_global('Inventory')
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_inventory(inv_type)
    inv_type = inv_type or 'hotbar'

    local w, h = self:get_inventory_size(inv_type)

    if !w or !h then return end

    local inventory = self:get_nv('inventory', {})[inv_type] or {}
    inventory.width, inventory.height = w, h
    inventory.type = inv_type

    for i = 1, h do
      inventory[i] = inventory[i] or {}

      for k = 1, w do
        inventory[i][k] = inventory[i][k] or {}
      end
    end

    return inventory
  end

  function player_meta:get_items(inv_type)
    local item_list = {}
    local inventories = !inv_type and self:get_nv('inventory', {}) or { self:get_nv('inventory', {})[inv_type] }

    for k, v in pairs(inventories) do
      for k1, v1 in pairs(v) do
        if !istable(v1) then continue end

        for k2, v2 in pairs(v1) do
          table.add(item_list, v2)
        end
      end
    end

    return item_list
  end

  function player_meta:get_slot(x, y, inv_type)
    local inv = self:get_inventory(inv_type)

    return inv[y][x]
  end

  function player_meta:get_first_in_slot(x, y, inv_type)
    return self:get_slot(x, y, inv_type)[1]
  end

  function player_meta:get_inventory_size(inv_type)
    local w, h = hook.run('GetInventorySize', self, inv_type)
    local inv_sizes = {
      ['main_inventory'] = { Config.get('inventory_width'), Config.get('inventory_height') },
      ['hotbar'] = { Config.get('hotbar_width'), Config.get('hotbar_height') },
      ['equipment'] = { Config.get('equipment_width'), Config.get('equipment_height') }
    }

    if w and h then
      return w, h
    elseif inv_sizes[inv_type] then
      return unpack(inv_sizes[inv_type])
    end
  end

  if SERVER then
    function player_meta:set_inventory(new_inv, inv_type)
      inv_type = inv_type or 'hotbar'

      local char = self:get_character()
      char.real_inventory[inv_type] = new_inv
      Characters.save(self, char)

      self:set_nv('inventory', char.real_inventory)
    end

    function player_meta:add_item(item_table, inv_type)
      if !item_table then return -1 end

      inv_type = inv_type or 'hotbar'

      local ply_inv = self:get_inventory(inv_type)

      if hook.run('CanItemTransfer', self, item_table, inv_type, x, y) != false then
        local y, x = self:find_stack_slot(item_table, inv_type)

        if x and y then
          table.insert(ply_inv[y][x], item_table.instance_id)

          item_table.slot_id = { y, x }
          item_table.inventory_type = inv_type

          self:set_inventory(ply_inv, inv_type)

          Item.network_item(self, item_table.instance_id)

          return y, x
        end

        y, x = self:find_empty_slot(inv_type)

        if hook.run('CanItemMove', self, item_table, inv_type, x, y) != false then
          table.insert(ply_inv[y][x], item_table.instance_id)

          item_table.slot_id = { y, x }
          item_table.inventory_type = inv_type

          self:set_inventory(ply_inv, inv_type)

          Item.network_item(self, item_table.instance_id)

          return y, x
        end
      end

      if inv_type == 'hotbar' then
        return self:add_item(item_table, 'main_inventory')
      end

      return false
    end

    function player_meta:give_item(id, instance_id, data, inv_type)
      if !id then return end

      local item_table

      if instance_id and instance_id > 0 then
        item_table = Item.find_instance_by_id(instance_id)
      else
        item_table = Item.create(id, data)
      end

      local x, y = self:add_item(item_table, inv_type or 'hotbar')

      if x and y and x != -1 and y != -1 then
        hook.run('OnItemGiven', self, item_table, x, y)
        return true
      elseif x == -1 then
        Flux.dev_print("Failed to add item to player's inventory (item_table is invalid)! "..tostring(item_table))
      else
        Flux.dev_print("Failed to add item to player's inventory (inv is full)! "..tostring(item_table))
      end

      return false
    end

    function player_meta:give_item_by_id(instance_id, inv_type)
      if !tonumber(instance_id) or tonumber(instance_id) <= 0 then return end

      local item_table = Item.find_instance_by_id(instance_id)

      if !item_table then return end

      local x, y = self:add_item(item_table, inv_type or 'hotbar')

      if x and y and x != -1 then
        hook.run('OnItemGiven', self, item_table, x, y)

        return true
      elseif x == -1 then
        Flux.dev_print("Failed to add item to player's inventory (item_table is invalid)! "..tostring(item_table))
      else
        Flux.dev_print("Failed to add item to player's inventory (inv is full)! "..tostring(item_table))
      end

      return false
    end

    function player_meta:take_item_by_id(instance_id)
      if !instance_id or instance_id < 1 then return end

      for k, v in pairs(self:get_nv('inventory', {})) do
        for k1, v1 in pairs(v) do
          if !istable(v1) then continue end

          for k2, v2 in pairs(v1) do
            if table.has_value(v2, instance_id) then
              local item_table = Item.find_instance_by_id(instance_id)

              table.remove_by_value(v[k1][k2], instance_id)
              self:set_inventory(v, k)

              if item_table then
                hook.run('OnItemTaken', self, item_table, k, k2, k1)
              end

              break
            end
          end
        end
      end
    end

    function player_meta:take_item(id, amount)
      local inv_instances = self:find_instances(id, amount)

      amount = amount or 1

      for i = 1, #inv_instances do
        if amount > 0 then
          self:take_item_by_id(inv_instances[i].instance_id)

          amount = amount - 1
        end
      end
    end

    function player_meta:transfer_item(instance_id, new_inv)
      local item_table = Item.find_instance_by_id(instance_id)

      if item_table and item_table.inventory_type != new_inv then
        local y, x = self:find_empty_slot(new_inv)

        if hook.run('CanItemTransfer', self, item_table, new_inv, x, y) != false then
          self:take_item_by_id(instance_id)
          self:give_item_by_id(instance_id, new_inv)
        end
      end
    end
  end

  function player_meta:find_empty_slot(inv_type)
    local ply_inv = self:get_inventory(inv_type)

    for i = 1, ply_inv.height do
      for k = 1, ply_inv.width do
        if #ply_inv[i][k] == 0 then
          return i, k
        end
      end
    end
  end

  function player_meta:find_stack_slot(item_table, inv_type)
    local ply_inv = self:get_inventory(inv_type)

    for i = 1, ply_inv.height do
      for k = 1, ply_inv.width do
        if hook.run('CanItemStack', self, item_table, inv_type, k, i) != false then
          return i, k
        end
      end
    end
  end

  -- A function to find an amount of instances of an item in player's inventory.
  function player_meta:find_instances(id, amount)
    local instances = Item.find_all_instances(id)
    local item_list = self:get_items()
    local to_ret = {}

    if instances then
      for k, v in pairs(instances) do
        for k1, v1 in pairs(item_list) do
          if v1 == k then
            table.insert(to_ret, v)

            if amount then
              amount = amount - 1

              if amount <= 0 then
                return to_ret
              end
            end
          end
        end
      end
    end

    return to_ret
  end

  -- A function to find the first instance of an item in player's inventory.
  function player_meta:find_item(id)
    return self:find_instances(id)[1]
  end

  function player_meta:has_item_by_id(instance_id, inv_type)
    for k, v in pairs(self:get_items(inv_type)) do
      if v == instance_id then
        return true
      end
    end

    return false
  end

  function player_meta:has_item(id)
    local instances = self:find_instances(id, 1)

    if instances[1] then
      return true
    end

    return false
  end

  function player_meta:has_item_equipped(id)
    local instances = self:find_instances(id, 1)
    local item_table = instances[1]

    if item_table and item_table:is_equipped() then
      return true
    end

    return false
  end
end
