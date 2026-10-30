--- Server-side player extensions of the Items plugin: creating the inventories of a player,
-- giving, taking and moving their items and showing them an inventory. These functions
-- synchronize the inventories they change right away.

local pairs = pairs
local table_add = table.Add
local player_meta = FindMetaTable('Player')

--- @warning [Internal]
-- Creates the player's default inventories.
function player_meta:create_inventories()
  local inventories = {}

  --- Called on the server to build the inventories of a player, every time their
  -- active character is set. Handlers create their inventories with `Inventory.new`
  -- and put them into `inventories` under the type of each one, or remove the entries
  -- that other handlers have put there, and return nothing; the Items plugin adds the
  -- main inventory, the hotbar, the pockets and the equipment slots this way. `Inventory.new`
  -- registers an inventory in `Inventories.stored` at once, so a handler that removes an
  -- entry also takes it out of there with `Inventories.stored[inventory.id] = nil`. Afterward
  -- every inventory in the table gets the player as its owner and receiver and the
  -- character as the holder of its items, the inventories are synchronized, and the items
  -- of the character are loaded into them.
  -- ```
  -- function PLUGIN:AdjustPlayerInventories(owner, inventories)
  --   local wallet = Inventory.new()
  --   wallet.title = 'Wallet'
  --   wallet.type = 'wallet'
  --   wallet:set_size(2, 1)
  --   inventories[wallet.type] = wallet
  -- end
  -- ```
  -- @param owner [Player The player the inventories are created for]
  -- @param inventories [Map The inventories of the player, keyed by inventory type,
  --   changed in place]
  hook.Run('AdjustPlayerInventories', self, inventories)

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
-- synchronized and the 'CharacterItemsLoaded' hook is run. Items that turn up after
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
    hook.Run('CharacterItemsLoaded', self, character, items)
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

      Inventories.stored[inventory.id] = nil
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
      Inventories.stored[inventory.id] = nil
    end
  end
end

--- Synchronize all the inventories that the player has.
function player_meta:sync_inventories()
  for _, inventory in pairs(self:get_inventories()) do
    inventory:sync()
  end
end

--- Synchronize only the specified inventory, if the player has it.
-- @param inv_type [String]
function player_meta:sync_inventory(inv_type)
  self:get_inventory(inv_type)?.:sync()
end

--- Give the player a certain item.
-- @param item_obj [Item]
-- @param inv_type=self.default_inventory or 'main_inventory' [String]
-- @return [Boolean was the item added successfully, String text of the error that occurred,
--   'error.inventory.missing' for a player without the inventory]
function player_meta:add_item(item_obj, inv_type)
  local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')

  if !inventory then return false, 'error.inventory.missing' end

  local success, error_text = inventory:add_item(item_obj)

  inventory:sync()

  return success, error_text
end

--- Give the player a certain item by its instance id.
-- @param instance_id [Number]
-- @param inv_type=self.default_inventory or 'main_inventory' [String]
-- @return [Boolean was the item added successfully, String text of the error that occurred,
--   'error.inventory.missing' for a player without the inventory]
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
-- @return [Boolean was the item added successfully, String text of the error that occurred,
--   'error.inventory.missing' for a player without the inventory]
function player_meta:give_item(id, amount, data, inv_type)
  local inventory = self:get_inventory(inv_type or self.default_inventory or 'main_inventory')

  if !inventory then return false, 'error.inventory.missing' end

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
-- @return [Boolean was the item taken successfully, String text of the error that occurred,
--   'error.inventory.invalid_item' when no inventory has the item or the player lacks the
--   inventory]
function player_meta:take_item(id, inv_type)
  if inv_type then
    local inventory = self:get_inventory(inv_type)

    if !inventory then return false, 'error.inventory.invalid_item' end

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
-- @return [Boolean have the items been taken successfully, String text of the error that occurred,
--   'error.inventory.not_enough_items' for a player without the inventory]
function player_meta:take_items(id, amount, inv_type)
  if inv_type then
    local inventory = self:get_inventory(inv_type)

    if !inventory then return false, 'error.inventory.not_enough_items' end

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
-- @return [Boolean was the item taken successfully, String text of the error that occurred,
--   'error.inventory.invalid_item' when the player does not have the item or lacks the
--   inventory]
function player_meta:take_item_by_id(instance_id, inv_type)
  if inv_type then
    local inventory = self:get_inventory(inv_type)

    if !inventory then return false, 'error.inventory.invalid_item' end

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
-- @return [Boolean was the item transferred successfully, String text of the error that occurred,
--   'error.inventory.invalid_item' when the item does not exist or the player lacks the inventory
--   it is in, 'error.inventory.missing' when the player lacks the target inventory]
function player_meta:transfer_item(instance_id, inv_type)
  local item_obj = Item.find_instance_by_id(instance_id)

  if !item_obj then return false, 'error.inventory.invalid_item' end
  if item_obj.inventory_type == inv_type then return end

  local old_inventory = self:get_inventory(item_obj.inventory_type)

  if !old_inventory then return false, 'error.inventory.invalid_item' end

  local new_inventory = self:get_inventory(inv_type)

  if !new_inventory then return false, 'error.inventory.missing' end

  local success, error_text = old_inventory:transfer_item(instance_id, new_inventory)

  if !success then return false, error_text end

  old_inventory:sync()
  new_inventory:sync()

  return true
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
-- receivers, tells the client to remove their windows and runs the 'InventoryClosed'
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

  hook.Run('InventoryClosed', self, closed_inventory)
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
