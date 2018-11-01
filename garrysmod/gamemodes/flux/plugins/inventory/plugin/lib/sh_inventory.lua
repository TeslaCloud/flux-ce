library.new 'inventory'

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_inventory(type)
    return self:get_nv('inventory', {})[type or 'hotbar'] or {}
  end

  function player_meta:set_inventory(new_inv, type)
    if SERVER then
      type = type or 'hotbar'

      local char = self:get_character()
      char.real_inventory[type] = new_inv
      character.save(self, char)

      return self:set_nv('inventory', char.real_inventory)
    end
  end

  function player_meta:get_slot(id, type)
    return self:get_inventory(type)[id] or {}
  end

  function player_meta:get_first_in_slot(id, type)
    return self:get_slot(id, type)[1]
  end

  if SERVER then
    function player_meta:add_item(item_table)
      if !item_table then return -1 end

      local ply_inv = self:get_inventory()
      local slots = self:get_character_data('inventory_slots', 8)

      for i = 1, slots do
        ply_inv[i] = ply_inv[i] or {}
        local ids = ply_inv[i]

        -- Empty slot
        if #ids == 0 then
          table.insert(ply_inv[i], item_table.instance_id)

          item_table.slot_id = i
          item_table.inventory_type = ply_inv.type or 'hotbar'

          self:set_inventory(ply_inv)

          item.network_item(self, item_table.instance_id)

          return i
        end

        local slot_table = item.find_instance_by_id(ids[1])

        if item_table.stackable and item_table.id == slot_table.id then
          if #ids < item_table.max_stack and plugin.call('ShouldItemStack', item_table, slot_table) != false then
            table.insert(ply_inv[i], item_table.instance_id)

            item_table.slot_id = i
            item_table.inventory_type = ply_inv.type or 'hotbar'

            self:set_inventory(ply_inv)

            item.network_item(self, item_table.instance_id)

            return i
          end
        end
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

      local slot = self:add_item(item_table)

      if slot and slot != -1 then
        hook.run('OnItemGiven', self, item_table, slot)
        return true
      elseif slot == -1 then
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

      local slot = self:add_item(item_table)

      if slot and slot != -1 then
        hook.run('OnItemGiven', self, item_table, slot)
        return true
      elseif slot == -1 then
        fl.dev_print("Failed to add item to player's inventory (item_table is invalid)! "..tostring(item_table))
      else
        fl.dev_print("Failed to add item to player's inventory (inv is full)! "..tostring(item_table))
      end

      return false
    end

    function player_meta:take_item_by_id(instance_id)
      if !instance_id or instance_id < 1 then return end

      local ply_inv = self:get_inventory()

      for slot, ids in ipairs(ply_inv) do
        if table.HasValue(ids, instance_id) then
          table.RemoveByValue(ply_inv[slot], instance_id)
          self:set_inventory(ply_inv)

          hook.run('OnItemTaken', self, instance_id, slot)

          break
        end
      end
    end

    function player_meta:take_item(id, amount)
      amount = amount or 1
      local invInstances = self:find_instances(id, amount)

      for i = 1, #invInstances do
        if amount > 0 then
          self:take_item_by_id(invInstances[i].instance_id)
          amount = amount - 1
        end
      end
    end
  end

  -- A function to find an amount of instances of an item in player's inventory.
  function player_meta:find_instances(id, amount)
    amount = amount or 1
    local instances = item.find_all_instances(id)
    local ply_inv = self:get_inventory()
    local to_ret = {}

    for k, v in pairs(instances) do
      for slot, ids in ipairs(ply_inv) do
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
  function player_meta:find_item(id)
    return self:find_instances(id)[1]
  end

  function player_meta:has_item_by_id(instance_id)
    local ply_inv = self:get_inventory()

    for slot, ids in ipairs(ply_inv) do
      if table.HasValue(ids, instance_id) then
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
