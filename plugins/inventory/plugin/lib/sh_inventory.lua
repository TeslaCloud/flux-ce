if !Inventories then
  PLUGIN:set_global('Inventories')
end

local stored = Inventories.stored or {}
Inventories.stored = stored

--- Returns all the inventories classes currently loaded on the server.
-- @return [Hash inventories]
function Inventories.all()
  return stored
end

--- Finds a specific inventory by its id.
-- @return [Inventory]
function Inventories.find(id)
  return stored[id]
end

do
  local player_meta = FindMetaTable('Player')

  --- Get one of the player's inventories by type.
  -- @param inv_type [String]
  -- @return [Inventory]
  function player_meta:get_inventory(inv_type)
    return self.inventories[inv_type]
  end

  --- Get all the player's inventories.
  -- @return [Hash inventories]
  function player_meta:get_inventories()
    return self.inventories or {}
  end

  --- Get items table from certain inventory or from all of them.
  -- Will return items from the specified inventory.
  -- @variant player_meta:get_items(inv_type)
  --   @param inv_type [String]
  -- Will return items from all the inventories that player has.
  -- @variant player_meta:get_items()
  -- @return [Hash items]
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

  --- Get only instance_ids from certain inventory or from all of them.
  -- Will return item ids only from the specified inventory.
  -- @variant player_meta:get_items_ids(inv_type)
  --   @param inv_type [String]
  -- Will return item ids from all the inventories that player has.
  -- @variant player_meta:get_items_ids()
  -- @return [Hash numbers]
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

  --- Get instance_ids from certain slot of the specified inventory.
  -- @param x [Number]
  -- @param y [Number]
  -- @param inv_type [String]
  -- @return [Hash numbers]
  function player_meta:get_slot(x, y, inv_type)
    return self:get_inventory(inv_type):get_slot(x, y)
  end

  --- Get first instance_id from certain slot of the specified inventory.
  -- @param x [Number]
  -- @param y [Number]
  -- @param inv_type [String]
  -- @return [Number]
  function player_meta:get_first_in_slot(x, y, inv_type)
    return self:get_inventory(inv_type):get_first_in_slot(x, y)
  end

  --- Get amount of items with certain id from the specified inventory or from all of them.
  -- Will return items count only from the specified inventory.
  -- @variant player_meta:get_items_count(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will return items count from all the inventories that player has.
  -- @variant player_meta:get_items_count(id)
  --   @param id [String]
  -- @return [Number]
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

  --- Get first item with certain id from the specified inventory or from all of them.
  -- Will return item only from the specified inventory.
  -- @variant player_meta:find_item(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will return item from all the inventories that player has.
  -- @variant player_meta:find_item(id)
  --   @param id [String]
  -- @return [Item]
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

  --- Get all items with certain id from the specified inventory or from all of them.
  -- Will return items only from the specified inventory.
  -- @variant player_meta:find_items(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will return items from all the inventories that player has.
  -- @variant player_meta:find_items(id)
  --   @param id [String]
  -- @return [Hash items]
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

  --- Checking if the player has certain item by its id.
  -- Will check only the specified inventory.
  -- @variant player_meta:has_item(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will check all the inventories that player has.
  -- @variant player_meta:has_item(id)
  --   @param id [String]
  -- @return [Boolean]
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

  --- Checking if the player has certain item by its instance id.
  -- Will check only the specified inventory.
  -- @variant player_meta:has_item_by_id(instance_id, inv_type)
  --   @param instance_id [Number]
  --   @param inv_type [String]
  -- Will check all the inventories that player has.
  -- @variant player_meta:has_item_by_id(instance_id)
  --   @param instance_id [Number]
  -- @return [Boolean]
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

  --- Checking if the player has certain item equipped by its id.
  -- @param id [Number]
  -- @return [Boolean]
  function player_meta:has_item_equipped(id)
    local item_table = self:find_item(id)

    if item_table and item_table:is_equipped() then
      return true, item_table
    end

    return false
  end

  --- Get item object by the weapon class.
  -- @param weapon_class [String]
  -- @return [Item]
  function player_meta:get_item_from_weapon(weapon_class)
    for k, v in pairs(self:get_items()) do
      if v:is_equipped() and v.weapon_class == weapon_class then
        return v
      end
    end
  end

  if SERVER then
    
    --- @warning [Internal]
    -- Creates default player's inventories.
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

    --- @warning [Internal]
    -- Loads player's inventories with the items they had.
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

    --- @warning [Internal]
    -- Deletes player's inventories from the server cache.
    function player_meta:delete_inventories()
      for k, v in pairs(self:get_inventories()) do
        if v.owner == self then
          stored[v.id] = nil
        end
      end
    end

    --- Synchronize all the inventories that player has.
    function player_meta:sync_inventories()
      for k, v in pairs(self:get_inventories()) do
        v:sync()
      end
    end

    --- Synchronize only the specified inventory.
    -- @param inv_type [String]
    function player_meta:sync_inventory(inv_type)
      self:get_inventory(inv_type):sync()
    end

    --- Give the player a certain item.
    -- @param item_table [Item]
    -- @param inv_type=player.default_inventory or 'main_inventory' [String]
    -- @return [Boolean was the item added successfully, String text of the error that occurred]
    function player_meta:add_item(item_table, inv_type)
      local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')
      local success, error_text = inventory:add_item(item_table)

      inventory:sync()

      return success, error_text
    end

    --- Give the player certain item by its instance id.
    -- @param instance_id [Number]
    -- @param inv_type [String]
    -- @return [Boolean was the item added successfully, String text of the error that occurred]
    function player_meta:add_item_by_id(instance_id, inv_type)
      return self:add_item(Item.find_instance_by_id(instance_id), inv_type)
    end

    --- Give the player a certain item(s) by id.
    -- ```
    -- -- Adds 10 test items to the player's inventory and sets their name to 'Some Item'.
    -- local success, error_text = player:give_item('test_item', 10, { name = 'Some Item' })
    -- if !success then
    --   -- Notifies the player of an error.
    --   player:notify(error_text)
    -- end
    -- ```
    -- @param id [String]
    -- @param amount [Number]
    -- @param data [Hash]
    -- @param inv_type=player.default_inventory or 'main_inventory' [String]
    -- @return [Boolean was the item added successfully, String text of the error that occurred]
    function player_meta:give_item(id, amount, data, inv_type)
      local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')
      local success, error_text = inventory:give_item(id, amount, data)

      inventory:sync()

      return success, error_text
    end

    --- Takes one item from the player.
    -- Takes item only from the specified inventory.
    -- @variant player_meta:take_item(id, inv_type)
    --   @param id [String]
    --   @param inv_type [String]
    -- Takes item from the inventory that has it.
    -- @variant player_meta:take_item(id)
    --   @param id [String]
    -- @return [Boolean was the item taken successfully, String text of the error that occurred]
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

        return false, 'error.inventory.invalid_item'
      end
    end

    --- Takes specified amount of items from the player.
    -- Takes items only from the specified inventory.
    -- @variant player_meta:take_item(id, inv_type)
    --   @param id [String]
    --   @param amount [Number]
    --   @param inv_type [String]
    -- Takes items from the inventory that has it.
    -- @variant player_meta:take_item(id)
    --   @param id [String]
    --   @param amount [Number]
    -- @return [Boolean have the items been taken successfully, String text of the error that occurred]
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

    --- Takes one specified item from the player.
    -- Takes item only from the specified inventory.
    -- @variant player_meta:take_item(id, inv_type)
    --   @param instance_id [Number]
    --   @param inv_type [String]
    -- Takes item from the inventory that has it.
    -- @variant player_meta:take_item(id)
    --   @param instance_id [Number]
    -- @return [Boolean was the item taken successfully, String text of the error that occurred]
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
          return false, 'error.inventory.invalid_item'
        end
      end
    end

    --- Transfers item to a specified inventory of the player.
    -- Takes item only from the specified inventory.
    -- @param instance_id [Number]
    -- @param inv_type [String]
    -- @return [Boolean was the item transferred successfully, String text of the error that occurred]
    function player_meta:transfer_item(instance_id, inv_type)
      local item_table = Item.find_instance_by_id(instance_id)
      local old_inventory = self:get_inventory(item_table.inventory_type)
      local new_inventory = self:get_inventory(inv_type)

      if item_table.inventory_type != inv_type then
        local success, error_text = old_inventory:transfer_item(instance_id, new_inventory)

        if success then
          old_inventory:sync()
          new_inventory:sync()

          return true
        else
          return false, error_text
        end
      end
    end

    --- Opens inventory window for the player.
    -- ```
    -- -- Creating new inventory
    -- local inventory = Inventory.new()
    -- inventory.title = 'Test inventory'
    -- inventory:set_size(4, 4)
    -- inventory.type = 'testing_inventory'
    -- inventory.multislot = false
    --
    -- -- Creating inventory window for a player
    -- player:open_inventory(inventory)
    -- ```
    -- @param inventory [Inventory]
    function player_meta:open_inventory(inventory)
      inventory:add_receiver(self)
      inventory:sync()

      Cable.send(self, 'fl_inventory_open', inventory.id)
    end
  end
end
