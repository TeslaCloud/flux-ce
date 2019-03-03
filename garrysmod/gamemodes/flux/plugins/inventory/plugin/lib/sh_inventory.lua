library.new 'inventory'

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_inventory(inv_type)
    inv_type = inv_type or 'hotbar'

    local inventory = self:get_nv('inventory', {})[inv_type] or {}
    inventory.width, inventory.height = self:get_inventory_size(inv_type)
    inventory.type = inv_type

    return inventory
  end

  function player_meta:get_items(inv_type)
    local item_list = {}
    local inventories = !inv_type and self:get_nv('inventory', {}) or { self:get_inventory(inv_type) }

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

  function player_meta:set_inventory(new_inv, inv_type)
    if SERVER then
    inv_type = inv_type or 'hotbar'

      local char = self:get_character()
      char.real_inventory[inv_type] = new_inv
      character.save(self, char)

      self:set_nv('inventory', char.real_inventory)
    end
  end

  function player_meta:get_slot(x, y, inv_type)
    local inv = self:get_inventory(inv_type)
    inv[y] = inv[y] or {}

    return inv[y][x] or {}
  end

  function player_meta:get_first_in_slot(x, y, inv_type)
    return self:get_slot(x, y, inv_type)[1]
  end

  function player_meta:get_inventory_size(inv_type)
    if inv_type == 'main_inventory' then
      return config.get('inventory_width'), config.get('inventory_height')
    elseif inv_type == 'hotbar' then
      return config.get('hotbar_width'), config.get('hotbar_height')
    else
      return hook.run('GetInventorySize', player, inv_type)
    end
  end

  if SERVER then
    function player_meta:add_item(item_table, inv_type)
      if !item_table then return -1 end

      inv_type = inv_type or 'hotbar'

      local ply_inv = self:get_inventory(inv_type)

      for i = 1, ply_inv.height do
        ply_inv[i] = ply_inv[i] or {}

        for k = 1, ply_inv.width do
          ply_inv[i][k] = ply_inv[i][k] or {}

          local ids = ply_inv[i][k]

          -- Empty slot
          if #ids == 0 then
            table.insert(ply_inv[i][k], item_table.instance_id)

            item_table.slot_id = { k, i }
            item_table.inventory_type = inv_type

            self:set_inventory(ply_inv, inv_type)

            item.network_item(self, item_table.instance_id)

            return k, i
          end

          local slot_table = item.find_instance_by_id(ids[1])

          if item_table.stackable and item_table.id == slot_table.id then
            if #ids < item_table.max_stack and plugin.call('ShouldItemStack', item_table, slot_table) != false then
              table.insert(ply_inv[i][k], item_table.instance_id)

              item_table.slot_id = { k, i }
              item_table.inventory_type = inv_type

              self:set_inventory(ply_inv, inv_type)

              item.network_item(self, item_table.instance_id)

              return k, i
            end
          end
        end
      end

      if inv_type == 'hotbar' then
        return self:add_item(item_table, 'main_inventory')
      end

      return false
    end

    function player_meta:give_item(id, instance_id, data)
      if !id then return end

      local item_table

      if instance_id and instance_id > 0 then
        item_table = item.find_instance_by_id(instance_id)
      else
        item_table = item.new(id, data)
      end

      local x, y = self:add_item(item_table, 'hotbar')

      if x and y and x != -1 and y != -1 then
        hook.run('OnItemGiven', self, item_table, x, y)
        return true
      elseif x == -1 then
        fl.dev_print("Failed to add item to player's inventory (item_table is invalid)! "..tostring(item_table))
      else
        fl.dev_print("Failed to add item to player's inventory (inv is full)! "..tostring(item_table))
      end

      return false
    end

    function player_meta:give_item_by_id(instance_id)
      if !tonumber(instance_id) or tonumber(instance_id) <= 0 then return end

      local item_table = item.find_instance_by_id(instance_id)

      if !item_table then return end

      local x, y = self:add_item(item_table, 'hotbar')

      if x and y and x != -1 then
        hook.run('OnItemGiven', self, item_table, x, y)

        return true
      elseif x == -1 then
        fl.dev_print("Failed to add item to player's inventory (item_table is invalid)! "..tostring(item_table))
      else
        fl.dev_print("Failed to add item to player's inventory (inv is full)! "..tostring(item_table))
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
              table.remove_by_value(v[k1][k2], instance_id)
              self:set_inventory(v, k)

              hook.run('OnItemTaken', self, instance_id, k2, k1)

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
  end

  -- A function to find an amount of instances of an item in player's inventory.
  function player_meta:find_instances(id, amount)
    local instances = item.find_all_instances(id)
    local item_list = self:get_items()
    local to_ret = {}

   amount = amount or 1

    for k, v in pairs(instances) do
      for k1, v1 in pairs(item_list) do
        if v1 == v then
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
