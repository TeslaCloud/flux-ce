--- Server side of the Inventory class: putting items in, taking them out, moving and
-- transferring them, and synchronizing the inventory with its receivers.

local next = next
local math_max = math.max
local table_has_value = table.HasValue
local table_remove_by_value = table.RemoveByValue

--- Add an item object to an inventory.
-- @variant Inventory:add_item(item_obj, x, y)
--   @param item_obj [Item]
--   @param x [Number]
--   @param y [Number]
-- In this case finds the best position for the item.
-- @variant Inventory:add_item(item_obj)
--   @param item_obj [Item]
-- @return [Boolean was the item added successfully, String text of the error that occurred]
function Inventory:add_item(item_obj, x, y)
  if !item_obj then return false, 'error.inventory.invalid_item' end

  local need_rotation = false
  local w, h = self:get_item_size(item_obj)

  if !x or !y or x < 1 or y < 1 or x + w - 1 > self.width or y + h - 1 > self.height then
    x, y, need_rotation = self:find_position(item_obj, w, h)
  end

  if x and y then
    item_obj.inventory_id = self.id
    item_obj.inventory_type = self.type
    item_obj.x = x
    item_obj.y = y

    if need_rotation then
      w, h = h, w

      item_obj.rotated = !item_obj.rotated
    end

    Item.set_holder(item_obj, self)

    local slots = self.slots
    local instance_id = item_obj.instance_id

    for i = y, y + h - 1 do
      local row = slots[i]

      for k = x, x + w - 1 do
        local stack = row[k]

        stack[#stack + 1] = instance_id
      end
    end

    --- Called on the server when an item has been put into an inventory by
    -- `Inventory:add_item`: when it is given, picked up, or loaded along with the
    -- inventories of a character. It is not run when an item arrives from another
    -- inventory through `Inventory:transfer_item`.
    -- @param item_obj [Item The item that has been added]
    -- @param inventory [Inventory The inventory the item is in now]
    -- @param x [Number Column of the slot the item has been placed in]
    -- @param y [Number Row of the slot the item has been placed in]
    hook.Run('OnItemAdded', item_obj, self, x, y)

    self:check_size()
  else
    return false, 'error.inventory.no_space'
  end

  return true
end

--- Add an item to an inventory by its instance id.
-- @variant Inventory:add_item_by_id(instance_id, x, y)
--   @param instance_id [Number]
--   @param x [Number]
--   @param y [Number]
-- In this case finds the best position for the item.
-- @variant Inventory:add_item_by_id(instance_id)
--   @param instance_id [Number]
-- @return [Boolean was the item added successfully, String text of the error that occurred]
function Inventory:add_item_by_id(instance_id, x, y)
  return self:add_item(Item.find_instance_by_id(instance_id), x, y)
end

--- Create an item and add it to an inventory.
-- ```
-- local success, error_text = inventory:give_item('test_item', 5, { name = 'Test Item #2' })
--
-- if success then
--   -- The changes are not sent to the clients until the inventory is synchronized.
--   inventory:sync()
-- end
-- ```
-- @param id [String]
-- @param amount=1 [Number]
-- @param data=nil [Map fields to override on the created items]
-- @return [Boolean was the item given successfully, String text of the error that occurred]
function Inventory:give_item(id, amount, data)
  amount = amount or 1

  for _i = 1, amount do
    local item_obj = Item.create(id, data)
    local success, error_text = self:add_item(item_obj)

    if !success then
      return success, error_text
    end

    --- Called on the server for every item that `Inventory:give_item` has created and
    -- added to an inventory, after `OnItemAdded`.
    -- @param item_obj [Item The new item instance]
    -- @param inventory [Inventory The inventory the item has been added to]
    -- @param data [Map The fields that were overridden on the item, or nil if there are
    --   none]
    hook.Run('OnItemGiven', item_obj, self, data)
  end

  return true
end

--- Take an item object from the inventory. An item that another inventory holds, such
-- as one inside of a container item in this inventory, is taken from that inventory,
-- which is synchronized then.
-- @param item_obj [Item]
-- @return [Boolean was the item taken successfully, String text of the error that occurred;
--   false also if the item is in no inventory]
function Inventory:take_item_table(item_obj)
  if !item_obj then return false, 'error.inventory.invalid_item' end

  if item_obj.inventory_id != self.id then
    local inventory = Inventories.find(item_obj.inventory_id)

    if inventory and inventory:has_item_by_id(item_obj.instance_id) then
      local success, error_text = inventory:take_item_table(item_obj)

      inventory:sync()

      return success, error_text
    end
  end

  if !item_obj.x or !item_obj.y then return false, 'error.inventory.invalid_item' end

  local x, y = item_obj.x, item_obj.y
  local w, h = self:get_item_size(item_obj)

  item_obj.inventory_id = nil
  item_obj.inventory_type = nil
  item_obj.x = nil
  item_obj.y = nil
  item_obj.rotated = false

  Item.set_holder(item_obj)

  local slots = self.slots
  local instance_id = item_obj.instance_id

  for i = y, y + h - 1 do
    local row = slots[i]

    for k = x, x + w - 1 do
      table_remove_by_value(row[k], instance_id)
    end
  end

  self:check_size()

  --- Called on the server when an item has been taken out of an inventory by one of the
  -- `take_` functions: when it is dropped, used up or taken away. The item no longer
  -- has its `inventory_id`, `inventory_type`, `x` and `y` fields at this point. It is not
  -- run when an item leaves for another inventory through `Inventory:transfer_item`.
  -- @param item_obj [Item The item that has been taken]
  -- @param inventory [Inventory The inventory the item was in]
  hook.Run('OnItemTaken', item_obj, self)

  return true
end

--- Take an item object from the inventory based on its id.
-- @param id [String]
-- @return [Boolean was the item taken successfully, String text of the error that occurred]
function Inventory:take_item(id)
  local item_obj = self:find_item(id)

  if item_obj then
    return self:take_item_by_id(item_obj.instance_id)
  end

  return false, 'error.inventory.invalid_item'
end

--- Take a certain amount of items from the inventory based on their id.
-- @param id [String]
-- @param amount [Number]
-- @return [Boolean was the item taken successfully, String text of the error that occurred]
function Inventory:take_items(id, amount)
  if self:get_items_count(id) < amount then
    return false, 'error.inventory.not_enough_items'
  end

  for _i = 1, amount do
    self:take_item(id)
  end

  return true
end

--- Take an item object from the inventory based on its instance id.
-- @param instance_id [Number]
-- @return [Boolean was the item taken successfully, String text of the error that occurred]
function Inventory:take_item_by_id(instance_id)
  return self:take_item_table(Item.find_instance_by_id(instance_id))
end

--- Takes an item out of the inventory for good, to be dropped into the world or removed,
-- between the `PreItemTransfer` and `ItemTransferred` hooks. Returns false without
-- running either hook when the item is not in this inventory. Otherwise
-- `PreItemTransfer` always runs; when a handler of it has taken the item out of the
-- inventory by itself, or the item cannot be taken out, `ItemTransferred` is not run and
-- the item is left where it is. Does not synchronize the inventory, so that a caller
-- that releases several items syncs once.
-- @param item_obj [Item]
-- @return [Boolean whether the item has been taken out]
-- @see [Inventory#destroy_item]
function Inventory:release_item(item_obj)
  if item_obj.inventory_id != self.id then
    return false
  end

  --- Called on the server right before an item is taken out of its inventory for good:
  -- when it is dropped into the world, used up, destroyed, sold or spent.
  -- `Inventory:transfer_item` runs the same hook for a transfer between two inventories.
  -- A handler may take the item out of the inventory by itself; the item is then left
  -- where the handler has put it, and `ItemTransferred` is not run.
  -- @param item_obj [Item The item that is about to be taken out]
  -- @param new_inventory [Inventory Always nil here: the item does not go to another
  --   inventory]
  -- @param old_inventory [Inventory The inventory the item is in]
  hook.Run('PreItemTransfer', item_obj, nil, self)

  if item_obj.inventory_id != self.id or !self:take_item_table(item_obj) then
    return false
  end

  --- Called on the server right after an item has been taken out of its inventory for
  -- good, before it is spawned in the world or removed. It is not run when the item could
  -- not be taken out. `Inventory:transfer_item` runs the same hook for a transfer between
  -- two inventories.
  -- @param item_obj [Item The item that has left]
  -- @param new_inventory [Inventory Always nil here]
  -- @param old_inventory [Inventory The inventory the item was in]
  hook.Run('ItemTransferred', item_obj, nil, self)

  return true
end

--- Takes an item out of the inventory with `Inventory:release_item`, synchronizes the
-- inventory and removes the item instance. Nothing is removed when the item could not be
-- taken out.
-- ```
-- if !inventory:destroy_item(item_obj) then
--   return false
-- end
-- ```
-- @param item_obj [Item]
-- @return [Boolean whether the item has been removed]
function Inventory:destroy_item(item_obj)
  local released = self:release_item(item_obj)

  self:sync()

  if released then
    Item.remove(item_obj)
  end

  return released
end

--- @warning [Internal]
-- Move the item inside the inventory.
-- @param instance_id [Number]
-- @param x [Number]
-- @param y [Number]
-- @param was_rotated [Boolean]
-- @return [Boolean was the item moved successfully, String text of the error that occurred]
function Inventory:move_item(instance_id, x, y, was_rotated)
  local item_obj = Item.find_instance_by_id(instance_id)

  if !item_obj then return false, 'error.inventory.invalid_item' end

  --- Called on the server before an item is moved to another slot of the inventory it
  -- is in. The Items plugin uses it to ask the `can_move` callback of the item and to
  -- keep items in disabled inventories where they are.
  -- @param item_obj [Item The item that is being moved]
  -- @param inventory [Inventory The inventory the item is in]
  -- @param x [Number Column of the target slot; a free position is looked for when it is
  --   nil or out of bounds]
  -- @param y [Number Row of the target slot]
  -- @return [Boolean Return false to prevent the move, String Error phrase that
  --   `Inventory:move_item` then returns to its caller]
  local success, error_text = hook.Run('CanItemMove', item_obj, self, x, y)

  if success == false then
    return false, error_text
  end

  local need_rotation = false
  local old_x, old_y = item_obj.x, item_obj.y
  local w, h = self:get_item_size(item_obj)
  local old_w, old_h = w, h

  if was_rotated then
    w, h = h, w
  end

  if !x or !y or x < 1 or y < 1 or x + w - 1 > self.width or y + h - 1 > self.height then
    x, y, need_rotation = self:find_position(item_obj, w, h)

    if !x or !y then
      return false, 'error.inventory.no_space'
    end
  elseif !self:slots_empty(x, y, w, h) then
    local overlap, new_x, new_y, new_rotation = self:overlaps_stack(item_obj, x, y, w, h)

    if overlap then
      x, y = new_x, new_y

      if new_rotation != was_rotated then
        need_rotation = true
      end
    elseif !self:overlaps_only_itself(instance_id, x, y, w, h) then
      return false, 'error.inventory.slot_occupied'
    end
  end

  item_obj.x = x
  item_obj.y = y

  if need_rotation then
    w, h = h, w
  end

  if was_rotated != need_rotation then
    item_obj.rotated = !item_obj.rotated
  end

  Item.mark_dirty(item_obj)

  local slots = self.slots

  for i = old_y, old_y + old_h - 1 do
    local row = slots[i]

    for k = old_x, old_x + old_w - 1 do
      table_remove_by_value(row[k], instance_id)
    end
  end

  for i = y, y + h - 1 do
    local row = slots[i]

    for k = x, x + w - 1 do
      local stack = row[k]

      stack[#stack + 1] = instance_id
    end
  end

  self:check_size()

  return true
end

--- @warning [Internal]
-- Move the item to another inventory.
-- @param instance_id [Number]
-- @param inventory [Inventory]
-- @param x [Number]
-- @param y [Number]
-- @param was_rotated [Boolean]
-- @return [Boolean was the item transferred successfully, String text of the error that occurred]
function Inventory:transfer_item(instance_id, inventory, x, y, was_rotated)
  local item_obj = Item.find_instance_by_id(instance_id)

  if !item_obj then return false, 'error.inventory.invalid_item' end

  --- Called on the server before an item is transferred from one inventory to another.
  -- The Items plugin also runs it, without a target slot, before a player picks an
  -- item up from the world into one of their inventories. The Items plugin uses it
  -- to enforce what equipment slots, pockets, container items and disabled inventories
  -- accept, and to ask the `can_transfer` callback of the item.
  -- @param item_obj [Item The item that is being transferred]
  -- @param inventory [Inventory The inventory the item is being transferred to]
  -- @param x [Number Column of the target slot; a free position is looked for when it is
  --   nil or out of bounds]
  -- @param y [Number Row of the target slot]
  -- @return [Boolean Return false to prevent the transfer, String Error phrase that
  --   `Inventory:transfer_item` then returns to its caller, or that the player who picks
  --   the item up is notified with]
  local success, error_text = hook.Run('CanItemTransfer', item_obj, inventory, x, y)

  if success == false then
    return false, error_text
  end

  local need_rotation = false
  local old_x, old_y = item_obj.x, item_obj.y
  local w, h = inventory:get_item_size(item_obj)
  local old_w, old_h = self:get_item_size(item_obj)

  if was_rotated then
    w, h = h, w
  end

  if !x or !y or x < 1 or y < 1 or x + w - 1 > inventory.width or y + h - 1 > inventory.height then
    x, y, need_rotation = inventory:find_position(item_obj, w, h)

    if !x or !y then
      return false, 'error.inventory.no_space'
    end
  elseif !inventory:slots_empty(x, y, w, h) then
    local overlap, new_x, new_y, new_rotation = inventory:overlaps_stack(item_obj, x, y, w, h)

    if overlap then
      x, y = new_x, new_y

      if new_rotation != was_rotated then
        need_rotation = true
      end
    else
      return false, 'error.inventory.slot_occupied'
    end
  end

  --- Called on the server right before an item changes its inventory.
  -- Besides a transfer between two inventories, as here, the Items plugin runs it
  -- when a player picks an item up from the world (without `old_inventory`, and only
  -- if the item fits), and `Inventory:release_item` runs it when an item leaves its
  -- inventory for good (with nil as `new_inventory`). The Items plugin uses it to
  -- call the `on_transfer` callback of the item, which is how equipable items get
  -- equipped and unequipped.
  -- @param item_obj [Item The item that is about to be moved]
  -- @param new_inventory [Inventory The inventory the item goes to, or nil if it leaves
  --   for the world or is removed]
  -- @param old_inventory [Inventory The inventory the item is in, or nil if it comes from
  --   the world]
  hook.Run('PreItemTransfer', item_obj, inventory, self)

  if item_obj.inventory_id != self.id then
    return false, 'error.inventory.invalid_item'
  end

  item_obj.inventory_id = inventory.id
  item_obj.inventory_type = inventory.type
  item_obj.x = x
  item_obj.y = y

  if need_rotation then
    w, h = h, w
  end

  if was_rotated != need_rotation then
    item_obj.rotated = !item_obj.rotated
  end

  Item.set_holder(item_obj, inventory)

  local old_slots = self.slots
  local new_slots = inventory.slots

  for i = old_y, old_y + old_h - 1 do
    local row = old_slots[i]

    for k = old_x, old_x + old_w - 1 do
      table_remove_by_value(row[k], instance_id)
    end
  end

  for i = y, y + h - 1 do
    local row = new_slots[i]

    for k = x, x + w - 1 do
      local stack = row[k]

      stack[#stack + 1] = instance_id
    end
  end

  self:check_size()
  inventory:check_size()

  --- Called on the server right after an item has changed its inventory. It is run in
  -- the same cases as `PreItemTransfer`: a transfer between two inventories, as here, a
  -- pickup from the world (without `old_inventory`, and only if the item did fit) and an
  -- item leaving its inventory for good through `Inventory:release_item` (with nil as
  -- `new_inventory`).
  -- @param item_obj [Item The item that has been moved]
  -- @param new_inventory [Inventory The inventory the item is in now, or nil if it has
  --   left for the world or has been removed]
  -- @param old_inventory [Inventory The inventory the item was in, or nil if it came
  --   from the world]
  hook.Run('ItemTransferred', item_obj, inventory, self)

  return true
end

--- @warning [Internal]
-- Move the whole stack inside the inventory.
-- @param instance_ids [List<Number> instance ids]
-- @param x [Number]
-- @param y [Number]
-- @param was_rotated [Boolean]
-- @return [Boolean have the items been moved successfully, String text of the error that occurred]
function Inventory:move_stack(instance_ids, x, y, was_rotated)
  local instance_id = instance_ids[1]
  local item_obj = Item.find_instance_by_id(instance_id)
  local old_x, old_y = item_obj.x, item_obj.y
  local slot = self:get_slot(old_x, old_y)
  local w, h = self:get_item_size(item_obj)

  if !table.equal(instance_ids, slot) and self:overlaps_itself(instance_id, x, y, w, h) then
    return true
  end

  for i = 1, #instance_ids do
    local success, error_text = self:move_item(instance_ids[i], x, y, was_rotated)

    if !success then
      return success, error_text
    end
  end

  return true
end

--- @warning [Internal]
-- Move the whole stack to another inventory.
-- @param instance_ids [List<Number> instance ids]
-- @param inventory [Inventory]
-- @param x [Number]
-- @param y [Number]
-- @param was_rotated [Boolean]
-- @return [Boolean have the items been transferred successfully, String text of the error that occurred]
function Inventory:transfer_stack(instance_ids, inventory, x, y, was_rotated)
  for i = 1, #instance_ids do
    local success, error_text = self:transfer_item(instance_ids[i], inventory, x, y, was_rotated)

    if !success then
      return success, error_text
    end
  end

  return true
end

--- Get the players that currently receive the inventory data.
-- @return [List<Player> players]
function Inventory:get_receivers()
  return self.receivers
end

--- Add a new receiver to the inventory. Does nothing if the player is a receiver already.
-- @param receiver [Player]
function Inventory:add_receiver(receiver)
  local receivers = self.receivers

  if table_has_value(receivers, receiver) then return end

  receivers[#receivers + 1] = receiver
end

--- Remove the receiver from the inventory.
-- @param receiver [Player]
function Inventory:remove_receiver(receiver)
  table_remove_by_value(self.receivers, receiver)
end

--- Checks if the player currently receives the inventory data, which is the case for
-- their own inventories and for the inventories that have been opened for them.
-- @param receiver [Player]
-- @return [Boolean]
function Inventory:has_receiver(receiver)
  return table_has_value(self.receivers, receiver)
end

--- Checks whether a player is entitled to have the inventory open. The owner always is.
-- The inside of a container item is for whoever carries the item, or stands within reach
-- of it while it lies in the world. Any other inventory that belongs to an entity is for
-- those within reach of that entity, and an inventory without an owner is for anyone.
-- The server closes an inventory for the receivers that fail this check.
-- @param receiver [Player]
-- @return [Boolean]
-- @see [Player#is_in_reach]
function Inventory:can_be_viewed_by(receiver)
  local owner = self.owner

  if owner == receiver then
    return true
  end

  if self.instance_id then
    local item_obj = Item.find_instance_by_id(self.instance_id)

    if !item_obj then
      return false
    end

    if IsValid(item_obj.entity) then
      return receiver:is_in_reach(item_obj.entity)
    end

    return receiver:has_item_by_id(self.instance_id)
  end

  if owner != nil then
    return receiver:is_in_reach(owner)
  end

  return true
end

--- Send inventory data to its receivers.
function Inventory:sync()
  local ids, networkable
  local receivers = self.receivers

  for index = #receivers, 1, -1 do
    local receiver = receivers[index]

    if IsValid(receiver) then
      if !ids then
        ids = self:get_items_ids()
        networkable = self:to_networkable()
      end

      for i = 1, #ids do
        Item.network_item(receiver, ids[i])
      end

      Cable.send(receiver, 'fl_inventory_sync', networkable)
    else
      table.remove(receivers, index)
    end
  end
end

--- @warning [Internal]
-- Check the size of the inventory and resize it if needed.
function Inventory:check_size()
  local infinite_width, infinite_height = self.infinite_width, self.infinite_height

  if !infinite_height and !infinite_width then return end

  local slots = self.slots
  local width = self.width
  local max_x, max_y = 0, 0

  for i = 1, self.height do
    local row = slots[i]

    for k = 1, width do
      if next(row[k]) != nil then
        max_x, max_y = math_max(max_x, k), i
      end
    end
  end

  if infinite_height then
    self.height = max_y + 1
  end

  if infinite_width then
    self.width = max_x + 1
  end

  self:rebuild()
  self:sync()
end

--- Disables the inventory, preventing the manipulation of items inside it.
-- @param disabled [Boolean]
function Inventory:set_disabled(disabled)
  self.disabled = disabled

  self:sync()
end
