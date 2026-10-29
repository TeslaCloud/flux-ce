--- Player extensions of the Inventory plugin: everything a player can do with their
-- inventories and the items in them.
-- A player has one inventory per type (`'main_inventory'`, `'hotbar'`, `'pockets'` and
-- so on), built by the `CreatePlayerInventories` hook when their character becomes
-- active. The inventories belong to the character, and the items of the character are
-- loaded from the database into them right afterward. The functions that look items up
-- work on both the server and the client; those that take an optional `inv_type` go
-- through all inventories of the player when it is omitted. On the server a player can
-- also be given items, have them taken or moved to another of their inventories, and be
-- shown an inventory. These functions synchronize the inventories they change right away.
--
-- The file also holds the registry of all inventories, `Inventories.all` and
-- `Inventories.find`.
-- @module [Player]

local pairs = pairs
local table_add = table.Add

if !Inventories then
  PLUGIN:set_global('Inventories')
end

local stored = Inventories.stored or {}
Inventories.stored = stored

--- Returns all the inventory classes currently loaded on the server.
-- @return [Map inventories]
function Inventories.all()
  return stored
end

--- Finds a specific inventory by its id.
-- @param id [Number]
-- @return [Inventory]
function Inventories.find(id)
  return stored[id]
end

if SERVER then
  --- Puts items that have been loaded from the database where they belong: items inside
  -- of a container item into the inventory of the container item, which is created if
  -- needed, and items of a character into the inventory of the player of the type they
  -- were saved in, or into the default inventory if the player has no such inventory.
  -- Items that already are in an inventory and items that belong elsewhere are skipped.
  -- Server-side only.
  -- @param items [List<Item>]
  -- @param owner=nil [Player the player whose character the items belong to]
  -- @return [List<Item> the items that did not fit anywhere]
  function Inventories.place_items(items, owner)
    local unplaced = {}

    for _, item_obj in ipairs(items) do
      if !item_obj.inventory_id then
        if item_obj.parent_id then
          local container = Item.find_instance_by_id(item_obj.parent_id)

          if container and container.create_inventory then
            if !container.inventory then
              container:create_inventory()
            end

            if !container.inventory:add_item(item_obj, item_obj.x, item_obj.y) then
              unplaced[#unplaced + 1] = item_obj
            end
          else
            unplaced[#unplaced + 1] = item_obj
          end
        elseif item_obj.character_id and IsValid(owner) then
          local x, y = item_obj.x, item_obj.y
          local inventory = owner:get_inventories()[item_obj.inventory_type]

          if inventory and x and y then
            if inventory:is_width_infinite() and x > inventory:get_width() then
              inventory:set_width(x + 1)
            end

            if inventory:is_height_infinite() and y > inventory:get_height() then
              inventory:set_height(y + 1)
            end
          else
            inventory = owner:get_inventories()[owner.default_inventory or 'main_inventory']
            x, y = nil, nil
          end

          if !inventory or !inventory:add_item(item_obj, x, y) then
            unplaced[#unplaced + 1] = item_obj
          end
        end
      end
    end

    return unplaced
  end
end

do
  local player_meta = FindMetaTable('Player')

  --- Get one of the player's inventories by type.
  -- @param inv_type [String]
  -- @return [Inventory, or nil if the player has no such inventory, as a player without a
  --   character has none]
  function player_meta:get_inventory(inv_type)
    return self:get_inventories()[inv_type]
  end

  --- Get all the player's inventories.
  -- @return [Map inventories]
  function player_meta:get_inventories()
    return self.inventories or {}
  end

  --- Get the items table from a certain inventory or from all of them.
  -- Will return items from the specified inventory.
  -- @variant player_meta:get_items(inv_type)
  --   @param inv_type [String]
  -- Will return items from all the inventories that the player has.
  -- @variant player_meta:get_items()
  -- @return [List<Item> items]
  function player_meta:get_items(inv_type)
    if inv_type then
      return self:get_inventory(inv_type):get_items()
    else
      local items = {}

      for _, inventory in pairs(self:get_inventories()) do
        table_add(items, inventory:get_items())
      end

      return items
    end
  end

  --- Get only instance_ids from a certain inventory or from all of them.
  -- Will return item ids only from the specified inventory.
  -- @variant player_meta:get_items_ids(inv_type)
  --   @param inv_type [String]
  -- Will return item ids from all the inventories that the player has.
  -- @variant player_meta:get_items_ids()
  -- @return [List<Number> numbers]
  function player_meta:get_items_ids(inv_type)
    if inv_type then
      return self:get_inventory(inv_type):get_items_ids()
    else
      local items = {}

      for _, inventory in pairs(self:get_inventories()) do
        table_add(items, inventory:get_items_ids())
      end

      return items
    end
  end

  --- Get instance_ids from a certain slot of the specified inventory.
  -- @param x [Number]
  -- @param y [Number]
  -- @param inv_type [String]
  -- @return [List<Number> numbers]
  function player_meta:get_slot(x, y, inv_type)
    return self:get_inventory(inv_type):get_slot(x, y)
  end

  --- Get the first instance_id from a certain slot of the specified inventory.
  -- @param x [Number]
  -- @param y [Number]
  -- @param inv_type [String]
  -- @return [Number]
  function player_meta:get_first_in_slot(x, y, inv_type)
    return self:get_inventory(inv_type):get_first_in_slot(x, y)
  end

  --- Get the amount of items with a certain id from the specified inventory or from all of them.
  -- Will return the items count only from the specified inventory.
  -- @variant player_meta:get_items_count(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will return the items count from all the inventories that the player has.
  -- @variant player_meta:get_items_count(id)
  --   @param id [String]
  -- @return [Number]
  function player_meta:get_items_count(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):get_items_count(id)
    else
      local count = 0

      for _, inventory in pairs(self:get_inventories()) do
        count += inventory:get_items_count(id)
      end

      return count
    end
  end

  --- Get the first item with a certain id from the specified inventory or from all of them.
  -- Will return the item only from the specified inventory.
  -- @variant player_meta:find_item(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will return the item from all the inventories that the player has.
  -- @variant player_meta:find_item(id)
  --   @param id [String]
  -- @return [Item]
  function player_meta:find_item(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):find_item(id)
    else
      for _, inventory in pairs(self:get_inventories()) do
        local item_obj = inventory:find_item(id)

        if item_obj then
          return item_obj
        end
      end
    end
  end

  --- Get all items with a certain id from the specified inventory or from all of them.
  -- Will return items only from the specified inventory.
  -- @variant player_meta:find_items(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will return items from all the inventories that the player has.
  -- @variant player_meta:find_items(id)
  --   @param id [String]
  -- @return [List<Item> items]
  function player_meta:find_items(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):find_items(id)
    else
      local items = {}

      for _, inventory in pairs(self:get_inventories()) do
        table_add(items, inventory:find_items(id))
      end

      return items
    end
  end

  --- Checking if the player has a certain item by its id.
  -- Will check only the specified inventory.
  -- @variant player_meta:has_item(id, inv_type)
  --   @param id [String]
  --   @param inv_type [String]
  -- Will check all the inventories that the player has.
  -- @variant player_meta:has_item(id)
  --   @param id [String]
  -- @return [Boolean, Item found item]
  function player_meta:has_item(id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):has_item(id)
    else
      for _, inventory in pairs(self:get_inventories()) do
        local found, item_obj = inventory:has_item(id)

        if found then
          return true, item_obj
        end
      end

      return false
    end
  end

  --- Checking if the player has a certain item by its instance id.
  -- Will check only the specified inventory.
  -- @variant player_meta:has_item_by_id(instance_id, inv_type)
  --   @param instance_id [Number]
  --   @param inv_type [String]
  -- Will check all the inventories that the player has.
  -- @variant player_meta:has_item_by_id(instance_id)
  --   @param instance_id [Number]
  -- @return [Boolean, Item found item]
  function player_meta:has_item_by_id(instance_id, inv_type)
    if inv_type then
      return self:get_inventory(inv_type):has_item_by_id(instance_id)
    else
      for _, inventory in pairs(self:get_inventories()) do
        local found, item_obj = inventory:has_item_by_id(instance_id)

        if found then
          return true, item_obj
        end
      end

      return false
    end
  end

  --- Checking if the player has a certain item equipped by its id.
  -- @param id [String]
  -- @return [Boolean, Item found item]
  function player_meta:has_item_equipped(id)
    local item_obj = self:find_item(id)

    if item_obj and item_obj:is_equipped() then
      return true, item_obj
    end

    return false
  end

  --- Get the item object by the weapon class.
  -- @param weapon_class [String]
  -- @return [Item]
  function player_meta:get_item_from_weapon(weapon_class)
    local items = self:get_items()

    for i = 1, #items do
      local item_obj = items[i]

      if item_obj.weapon_class == weapon_class and item_obj.is_equipped and item_obj:is_equipped() then
        return item_obj
      end
    end
  end

  --- Get the item of the weapon that the player is holding in their hands.
  -- @return [Item]
  function player_meta:get_active_weapon_item()
    local weapon = self:GetActiveWeapon()

    if IsValid(weapon) then
      return self:get_item_from_weapon(weapon:GetClass())
    end
  end

  if SERVER then
    --- @warning [Internal]
    -- Creates the player's default inventories.
    function player_meta:create_inventories()
      local inventories = {}

      --- Called on the server to build the inventories of a player, every time their
      -- active character is set. Handlers create their inventories with `Inventory.new`
      -- and put them into `inventories` under the type of each one; the Inventory plugin
      -- adds the main inventory, the hotbar, the pockets and the equipment slots this
      -- way. Afterward every inventory in the table gets the player as its owner and
      -- receiver and the character as the holder of its items, the inventories are
      -- synchronized, and the items of the character are loaded into them.
      -- ```
      -- function PLUGIN:CreatePlayerInventories(owner, inventories)
      --   local wallet = Inventory.new()
      --   wallet.title = 'Wallet'
      --   wallet.type = 'wallet'
      --   wallet:set_size(2, 1)
      --   inventories[wallet.type] = wallet
      -- end
      -- ```
      -- @param owner [Player The player the inventories are created for]
      -- @param inventories [Map The inventories of the player, keyed by inventory type,
      --   to be filled in place]
      hook.Run('CreatePlayerInventories', self, inventories)

      local character = self:get_character()
      local character_id = istable(character) and tonumber(character.id) or nil

      for _, inventory in pairs(inventories) do
        if !self.default_inventory and inventory:is_default() then
          self.default_inventory = inventory.type
        end

        inventory:add_receiver(self)
        inventory.owner = self
        inventory.character_id = character_id
      end

      self.inventories = inventories
      self:sync_inventories()
      self:load_inventories()
    end

    --- @warning [Internal]
    -- Loads the items of the player's active character from the database into the
    -- inventories of the player, which may take a moment. Until the items are there,
    -- `loading_items` is true on the player. Once they are, the inventories are
    -- synchronized and the 'OnCharacterItemsLoaded' hook is run. Items that turn up after
    -- the player has switched to another character are dropped without being used.
    function player_meta:load_inventories()
      local character = self:get_character()
      local character_id = istable(character) and tonumber(character.id) or nil
      local inventories = self.inventories

      if !character_id then return end

      self.loading_items = true

      Item.load_character(character_id, function(items)
        if !IsValid(self) or self.inventories != inventories then return end

        items = Item.register_loaded(items)

        self.loading_items = nil
        self.unplaced_items = Inventories.place_items(items, self)
        self:sync_inventories()
        self:give_default_items()

        --- Called on the server once the items of a player's active character have been
        -- loaded from the database and put into the inventories of the player, which have
        -- been synchronized. The Items plugin calls the `on_loadout` callbacks of the items
        -- here if the player is alive.
        -- @param owner [Player]
        -- @param character [Character the active character of the player]
        -- @param items [List<Item> the items of the character, along with the contents of
        --   its container items]
        hook.Run('OnCharacterItemsLoaded', self, character, items)
      end)
    end

    --- @warning [Internal]
    -- Gives the player's active character its starting items through the
    -- 'AddDefaultItems' hook, if it has not had them yet. Called the first time a new
    -- character is loaded, once its inventories exist and its items are there. The
    -- character is saved right afterward, so that it gets them only once.
    function player_meta:give_default_items()
      local character = self:get_character()

      if !Characters.get_custom_data(character, 'default_items_pending') then return end

      Characters.set_custom_data(character, 'default_items_pending', nil)

      --- Called on the server the first time a character is loaded after it has been
      -- created, so that plugins can give it its starting items. The inventories of the
      -- player exist and the items of the character are in them by then, so handlers give
      -- items with `Player:give_item`. It is run with `Plugin.call`, so gamemode functions
      -- do not receive it.
      -- ```
      -- function PLUGIN:AddDefaultItems(owner, char)
      --   owner:give_item('bandage', 2)
      -- end
      -- ```
      -- @param owner [Player The player who has loaded the character]
      -- @param char [Character The new character]
      Plugin.call('AddDefaultItems', self, character)

      self:save_character()
    end

    --- @warning [Internal]
    -- Writes the changes of the items in the player's inventories, and of the items of the
    -- character that could not be put into them, and makes the server forget them. Called
    -- when the character is no longer in use. The inventories of the container items among
    -- them are closed and deleted from the server cache; the player's own inventories are
    -- left alone.
    -- @param defer=false [Boolean do it on the next tick, so that what is saved along with
    --   the character in the meantime is not lost]
    function player_meta:unload_items(defer)
      local items = self:get_items()

      table_add(items, self.unplaced_items or {})

      self.unplaced_items = nil
      self.loading_items = nil

      for _, item_obj in ipairs(items) do
        local inventory = item_obj.inventory

        if inventory and inventory.instance_id == item_obj.instance_id then
          for _, receiver in ipairs(table.Copy(inventory.receivers)) do
            if IsValid(receiver) then
              receiver:close_inventory(inventory)
            end
          end

          stored[inventory.id] = nil
        end
      end

      if defer then
        timer.Simple(0, function()
          Item.unload(items)
        end)
      else
        Item.unload(items)
      end
    end

    --- @warning [Internal]
    -- Deletes the player's inventories from the server cache.
    function player_meta:delete_inventories()
      for _, inventory in pairs(self:get_inventories()) do
        if inventory.owner == self then
          stored[inventory.id] = nil
        end
      end
    end

    --- Synchronize all the inventories that the player has.
    function player_meta:sync_inventories()
      for _, inventory in pairs(self:get_inventories()) do
        inventory:sync()
      end
    end

    --- Synchronize only the specified inventory.
    -- @param inv_type [String]
    function player_meta:sync_inventory(inv_type)
      self:get_inventory(inv_type):sync()
    end

    --- Give the player a certain item.
    -- @param item_obj [Item]
    -- @param inv_type=self.default_inventory or 'main_inventory' [String]
    -- @return [Boolean was the item added successfully, String text of the error that occurred]
    function player_meta:add_item(item_obj, inv_type)
      local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')
      local success, error_text = inventory:add_item(item_obj)

      inventory:sync()

      return success, error_text
    end

    --- Give the player a certain item by its instance id.
    -- @param instance_id [Number]
    -- @param inv_type=self.default_inventory or 'main_inventory' [String]
    -- @return [Boolean was the item added successfully, String text of the error that occurred]
    function player_meta:add_item_by_id(instance_id, inv_type)
      return self:add_item(Item.find_instance_by_id(instance_id), inv_type)
    end

    --- Give the player a certain item(s) by id.
    -- ```
    -- -- Adds 10 test items to the player's inventory and sets their name to 'Some Item'.
    -- local success, error_text = target:give_item('test_item', 10, { name = 'Some Item' })
    -- if !success then
    --   -- Notifies the player of an error.
    --   target:notify(error_text)
    -- end
    -- ```
    -- @param id [String]
    -- @param amount=1 [Number]
    -- @param data=nil [Map fields to override on the created items]
    -- @param inv_type=self.default_inventory or 'main_inventory' [String]
    -- @return [Boolean was the item added successfully, String text of the error that occurred]
    function player_meta:give_item(id, amount, data, inv_type)
      local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')
      local success, error_text = inventory:give_item(id, amount, data)

      inventory:sync()

      return success, error_text
    end

    --- Takes one item from the player.
    -- Takes the item only from the specified inventory.
    -- @variant player_meta:take_item(id, inv_type)
    --   @param id [String]
    --   @param inv_type [String]
    -- Takes the item from the inventory that has it.
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
        for _, inventory in pairs(self:get_inventories()) do
          if inventory:has_item(id) then
            local success, error_text = inventory:take_item(id)

            inventory:sync()

            return success, error_text
          end
        end

        return false, 'error.inventory.invalid_item'
      end
    end

    --- Takes the specified amount of items from the player.
    -- Takes items only from the specified inventory.
    -- @variant player_meta:take_items(id, amount, inv_type)
    --   @param id [String]
    --   @param amount [Number]
    --   @param inv_type [String]
    -- Takes items from the inventory that has them.
    -- @variant player_meta:take_items(id, amount)
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
          for _, inventory in pairs(self:get_inventories()) do
            local count = math.min(amount, inventory:get_items_count(id))

            if count > 0 then
              inventory:take_items(id, count)
              inventory:sync()

              amount -= count
            end
          end

          return true
        end
      end
    end

    --- Takes one specified item from the player.
    -- Takes the item only from the specified inventory.
    -- @variant player_meta:take_item_by_id(instance_id, inv_type)
    --   @param instance_id [Number]
    --   @param inv_type [String]
    -- Takes the item from the inventory that has it.
    -- @variant player_meta:take_item_by_id(instance_id)
    --   @param instance_id [Number]
    -- @return [Boolean was the item taken successfully, String text of the error that occurred]
    function player_meta:take_item_by_id(instance_id, inv_type)
      if inv_type then
        local inventory = self:get_inventory(inv_type)
        local success, error_text = inventory:take_item_by_id(instance_id)

        inventory:sync()

        return success, error_text
      else
        local has, item_obj = self:has_item_by_id(instance_id)

        if has then
          local inventory = self:get_inventory(item_obj.inventory_type)
          local success, error_text = inventory:take_item_table(item_obj)

          inventory:sync()

          return success, error_text
        else
          return false, 'error.inventory.invalid_item'
        end
      end
    end

    --- Transfers an item to a specified inventory of the player.
    -- Takes the item only from the specified inventory.
    -- Does nothing and returns nothing if the item is in that inventory already.
    -- ```
    -- -- Puts the item on the player's hotbar.
    -- local success, error_text = target:transfer_item(item_obj.instance_id, 'hotbar')
    --
    -- if success == false then
    --   target:notify(error_text)
    -- end
    -- ```
    -- @param instance_id [Number]
    -- @param inv_type [String]
    -- @return [Boolean was the item transferred successfully, String text of the error that occurred]
    function player_meta:transfer_item(instance_id, inv_type)
      local item_obj = Item.find_instance_by_id(instance_id)
      local old_inventory = self:get_inventory(item_obj.inventory_type)
      local new_inventory = self:get_inventory(inv_type)

      if item_obj.inventory_type != inv_type then
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

    --- Opens an inventory window for the player and makes them a receiver of the inventory.
    -- The server closes it again as soon as Inventory:can_be_viewed_by fails for the player,
    -- for example when they walk away from the entity the inventory belongs to.
    -- ```
    -- -- Creating new inventory
    -- local inventory = Inventory.new()
    -- inventory.title = 'Test inventory'
    -- inventory:set_size(4, 4)
    -- inventory.type = 'testing_inventory'
    -- inventory.multislot = false
    --
    -- -- Creating an inventory window for a player
    -- target:open_inventory(inventory)
    -- ```
    -- @param inventory [Inventory]
    function player_meta:open_inventory(inventory)
      inventory:add_receiver(self)
      inventory:sync()

      Cable.send(self, 'fl_inventory_open', inventory.id)
    end

    --- Opens all the inventories the other player has. The server closes them again as soon
    -- as the other player is out of reach; call close_player_inventory to close them earlier.
    -- @param target [Player]
    -- @see [Player#is_in_reach]
    function player_meta:open_player_inventory(target)
      local inventory_ids = {}

      for _, inventory in pairs(target:get_inventories()) do
        inventory:add_receiver(self)
        inventory:sync()

        inventory_ids[#inventory_ids + 1] = inventory.id
      end

      Cable.send(self, 'fl_open_player_inventory', target, inventory_ids)
    end

    --- Closes inventories that were opened for the player: removes the player from their
    -- receivers, tells the client to remove their windows and runs the 'OnInventoryClosed'
    -- hook once, with the first of them. The player's own inventories and inventories that
    -- are not open for the player are skipped.
    -- @param inventories [List<Inventory>]
    function player_meta:close_inventories(inventories)
      local closed_inventory

      for _, inventory in pairs(inventories) do
        if inventory.owner != self and inventory:has_receiver(self) then
          inventory:remove_receiver(self)

          Cable.send(self, 'fl_inventory_close', inventory.id)

          closed_inventory = closed_inventory or inventory
        end
      end

      if !closed_inventory then return end

      hook.Run('OnInventoryClosed', self, closed_inventory)
    end

    --- Closes an inventory that was opened for the player with open_inventory.
    -- @param inventory [Inventory]
    -- @see [Player#close_inventories]
    function player_meta:close_inventory(inventory)
      self:close_inventories({ inventory })
    end

    --- Closes the inventories of another player that were opened with open_player_inventory.
    -- @param target [Player]
    -- @see [Player#close_inventories]
    function player_meta:close_player_inventory(target)
      self:close_inventories(target:get_inventories())
    end
  end
end
