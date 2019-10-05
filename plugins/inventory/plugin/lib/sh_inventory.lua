if !Inventories then
  PLUGIN:set_global('Inventories')
end

local stored = Inventories.stored or {}
Inventories.stored = stored

function Inventories.all()
  return stored
end

function Inventories.find(id)
  return stored[id]
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_inventory(inv_type)
    return self.inventories[inv_type]
  end

  function player_meta:get_inventories()
    return self.inventories or {}
  end

  function player_meta:get_items(inv_type)
    if inv_type then
      return self:get_inventory(inv_type):get_items()
    else
      local items = {}

      for k, v in pairs(self:get_inventories()) do
        table.add(items, v:get_items())
      end

      return items
    end
  end

  function player_meta:get_items_ids(inv_type)
    if inv_type then
      return self:get_inventory(inv_type)
    else
      local items = {}

      for k, v in pairs(self:get_inventories()) do
        table.add(items, v:get_items_ids())
      end

      return items
    end
  end
  
  function player_meta:get_slot(x, y, inv_type)
    return self:get_inventory(inv_type):get_slot(x, y)
  end

  function player_meta:get_first_in_slot(x, y, inv_type)
    return self:get_inventory(inv_type):get_first_in_slot(x, y)
  end

  function player_meta:get_items_count(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):get_items_count(id)
    else
      local count = 0

      for k, v in pairs(self:get_inventories()) do
        count = count + v:get_items_count(id)
      end

      return count
    end
  end

  function player_meta:find_item(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):find_item(id)
    else
      for k, v in pairs(self:get_inventories()) do
        local item_table = v:find_item(id)

        if item_table then
          return item_table
        end
      end
    end
  end

  function player_meta:find_items(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):find_items(id)
    else
      local items = {}

      for k, v in pairs(self:get_inventories()) do
        table.add(items, v:find_items(id))
      end

      return items
    end
  end

  function player_meta:has_item(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):has_item(id)
    else
      for k, v in pairs(self:get_inventories()) do
        local found, item_table = v:has_item(id)

        if found then
          return true, item_table
        end
      end

      return false
    end
  end

  function player_meta:has_item_by_id(instance_id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):has_item_by_id(instance_id)
    else
      for k, v in pairs(self:get_inventories()) do
        local found, item_table = v:has_item_by_id(instance_id)

        if found then
          return true, item_table
        end
      end

      return false
    end
  end

  function player_meta:has_item_equipped(id)
    local item_table = self:find_item(id)

    if item_table and item_table:is_equipped() then
      return true, item_table
    end

    return false
  end

  function player_meta:get_item_from_weapon(weapon_class)
    for k, v in pairs(self:get_items()) do
      if v:is_equipped() and v.weapon_class == weapon_class then
        return v
      end
    end
  end

  if SERVER then
    function player_meta:create_inventories()
      local inventories = {}

      hook.run('CreatePlayerInventories', self, inventories)

      for k, v in pairs(inventories) do
        if !self.default_inventory and v:is_default() then
          self.default_inventory = v.type
        end

        v:add_receiver(self)
        v.owner = self
      end

      self.inventories = inventories
      self:load_inventories()
      self:sync_inventories()

      Cable.send(self, 'fl_create_hotbar')
    end

    function player_meta:load_inventories()
      local item_ids = (self:get_character().item_ids or ''):split(',')

      for k, v in pairs(item_ids) do
        v = tonumber(v)

        local item_table = Item.find_instance_by_id(v)

        if item_table and item_table.inventory_type then
          local x, y = item_table.x, item_table.y
          local inventory_type = item_table.inventory_type
          local inventory = self:get_inventory(inventory_type)

          if inventory:is_width_infinite() and x > inventory:get_width() then
            inventory:set_width(x + 1)
          end

          if inventory:is_height_infinite() and y > inventory:get_height() then
            inventory:set_height(y + 1)
          end

          inventory:add_item(item_table, x, y)
        end
      end
    end

    function player_meta:delete_inventories()
      for k, v in pairs(self:get_inventories()) do
        if v.owner == self then
          stored[v.id] = nil
        end
      end
    end

    function player_meta:sync_inventories()
      for k, v in pairs(self:get_inventories()) do
        v:sync()
      end
    end

    function player_meta:sync_inventory(inv_type)
      self:get_inventory(inv_type):sync()
    end

    function player_meta:add_item(item_table, inv_type)
      local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')
      local success, error_text = inventory:add_item(item_table)

      inventory:sync()

      return success, error_text
    end

    function player_meta:add_item_by_id(instance_id, inv_type)
      return self:add_item(Item.find_instance_by_id(instance_id), inv_type)
    end

    function player_meta:give_item(id, data, amount, inv_type)
      local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')
      local success, error_text = inventory:give_item(id, data, amount)

      inventory:sync()

      return success, error_text
    end

    function player_meta:take_item(id, inv_type)
      if inv_type then
        local inventory = self:get_inventory(inv_type)
        local success, error_text = inventory:take_item(id)

        inventory:sync()

        return success, error_text
      else
        for k, v in pairs(self:get_inventories()) do
          if v:has_item(id) then
            local success, error_text = v:take_item(id)

            v:sync()

            return success, error_text
          end
        end

        return false, 'error.inventory.item_not_found'
      end
    end

    function player_meta:take_items(id, amount, inv_type)
      if inv_type then
        local inventory = self:get_inventory(inv_type)
        local success, error_text = inventory:take_items(id, amount)

        inventory:sync()

        return success, error_text
      else
        if self:get_items_count(id) < amount then
          return false, 'error.inventory.not_enough_items'
        else
          for k, v in pairs(self:get_inventories()) do
            if amount > 0 and v:has_item(id) then
              v:take_item(id)
              v:sync()

              amount = amount - 1
            end
          end

          return true
        end
      end
    end

    function player_meta:take_item_by_id(instance_id, inv_type)
      if inv_type then
        local inventory = self:get_inventory(inv_type)
        local success, error_text = inventory:take_item_by_id(instance_id)

        inventory:sync()

        return success, error_text
      else
        local has, item_table = self:has_item_by_id(instance_id)

        if has then
          local inventory = self:get_inventory(item_table.inventory_type)
          local success, error_text = inventory:take_item_table(item_table)

          inventory:sync()

          return success, error_text
        else
          return false, 'error.inventory.item_not_found'
        end
      end
    end

    function player_meta:transfer_item(instance_id, inv_type)
      local item_table = Item.find_instance_by_id(instance_id)
      local old_inventory = self:get_inventory(item_table.inventory_type)
      local new_inventory = self:get_inventory(inv_type)

      if item_table.inventory_type != inv_type then
        old_inventory:transfer_item(instance_id, new_inventory)
        old_inventory:sync()
        new_inventory:sync()
      end
    end

    function player_meta:open_inventory(inventory)
      inventory:add_receiver(self)
      inventory:sync()

      Cable.send(self, 'fl_inventory_open', inventory.id)
    end
  end
end
