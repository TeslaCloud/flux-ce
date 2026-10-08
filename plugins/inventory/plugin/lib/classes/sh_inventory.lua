--- An Inventory is a grid of slots that holds item instances.
-- Every inventory has an id, under which it is found with `Inventories.find`, a `type`
-- that says what it is for, a `title` and a size in slots. Each slot holds a list of
-- instance ids: more than one when stackable items are stacked. If `multislot` is true,
-- an item covers `width` by `height` slots, swapped when it is rotated; otherwise every
-- item takes one slot. An item in an inventory carries its position in its
-- `inventory_id`, `inventory_type`, `x`, `y` and `rotated` fields.
--
-- Inventories are created and changed on the server. Items are put in with
-- `Inventory:add_item` or `Inventory:give_item`, taken out with the `take_` functions and
-- moved with `Inventory:move_item` and `Inventory:transfer_item`, which run the
-- `CanItemMove`, `CanItemTransfer`, `PreItemTransfer` and `ItemTransferred` hooks. The
-- changes reach the clients when `Inventory:sync` is called, which sends the contents of
-- the inventory to the players listed as its receivers. On the client an inventory is
-- a copy of what was last synchronized, and `Inventory:create_panel` displays it.
--
-- Other fields: `owner` is the player or entity the inventory belongs to, and
-- `instance_id` is the instance id of the container item it is the inside of. On the
-- server, `default` marks the inventory of a player that items go to when none is named,
-- and `infinite_width` and `infinite_height` make the inventory resize itself to keep
-- an empty column or row past its last item.

--- The inventory class is used to manage a player's items,
-- transferring them from one player or object to another,
-- using the same interface and functionality.
class 'Inventory'

--- Initializes the new inventory class
-- and loads it to the server cache.
-- ```
-- -- Creating a new inventory
-- local inventory = Inventory.new()
-- inventory.title = 'Test inventory'
-- inventory:set_size(4, 4)
-- inventory.type = 'testing_inventory'
-- inventory.multislot = false
-- ```
-- @param id=nil [Number id of the inventory; client-side only, the server assigns ids itself]
function Inventory:init(id)
  self.title = 'ui.inventory.title'
  self.icon = nil
  self.type = 'default'
  self.width = 1
  self.height = 1
  self.slots = {}
  self.multislot = true
  self.disabled = false

  if SERVER then
    self.infinite_width = false
    self.infinite_height = false
    self.default = false
    self.receivers = {}

    id = table.insert(Inventories.stored, self)
  else
    Inventories.stored[id] = self
  end

  self.id = id
end

--- Returns the values of the inventory
-- that will be sent to the client.
-- @return [Map]
function Inventory:to_networkable()
  return {
    id = self.id,
    title = self.title,
    icon = self.icon,
    inv_type = self.type,
    width = self.width,
    height = self.height,
    slots = self.slots,
    multislot = self.multislot,
    disabled = self.disabled,
    owner = self.owner,
    instance_id = self.instance_id
  }
end

--- Sets the width of the inventory and rebuilds its slots.
-- @param width [Number width in a number of slots]
function Inventory:set_width(width)
  self.width = width

  self:rebuild()
end

--- Sets the height of the inventory and rebuilds its slots.
-- @param height [Number height in a number of slots]
function Inventory:set_height(height)
  self.height = height

  self:rebuild()
end

--- Sets the width and height of the inventory and rebuilds its slots.
-- @param width [Number width in a number of slots]
-- @param height [Number height in a number of slots]
function Inventory:set_size(width, height)
  self.width = width
  self.height = height

  self:rebuild()
end

--- Gets the X axis size of the inventory in a number of slots.
-- @return [Number]
function Inventory:get_width()
  return self.width
end

--- Gets the Y axis size of the inventory in a number of slots.
-- @return [Number]
function Inventory:get_height()
  return self.height
end

--- Gets the X and Y axes size of the inventory in a number of slots.
-- @return [Number, Number]
function Inventory:get_size()
  return self.width, self.height
end

--- Get the type of the inventory.
-- @return [String]
function Inventory:get_type()
  return self.type
end

--- Get the slots grid.
-- @return [Map slots, indexed by y and then by x; every slot is an array of instance ids]
function Inventory:get_slots()
  return self.slots
end

--- Get the entity this inventory belongs to.
-- @return [Entity]
function Inventory:get_owner()
  return self.owner
end

--- Checks if the inventory is multislot.
-- @return [Boolean]
function Inventory:is_multislot()
  return self.multislot
end

--- Checks if the inventory is disabled.
-- @return [Boolean]
function Inventory:is_disabled()
  return self.disabled
end

--- Checks if the inventory has infinite width.
-- @return [Boolean]
function Inventory:is_width_infinite()
  return self.infinite_width
end

--- Checks if the inventory has infinite height.
-- @return [Boolean]
function Inventory:is_height_infinite()
  return self.infinite_height
end

--- Checks if the inventory is default.
-- If there's no certain inventory specified,
-- the default one is used for it.
-- @see [player_meta#add_item]
-- @return [Boolean]
function Inventory:is_default()
  return self.default
end

--- @warning [Internal]
-- Rebuilds the inventory slots hash.
function Inventory:rebuild()
  for i = 1, self.height do
    self.slots[i] = self.slots[i] or {}

    for k = 1, self.width do
      self.slots[i][k] = self.slots[i][k] or {}
    end
  end
end

--- Get item objects that the inventory contains.
-- Also includes items from the containers.
-- @return [List<Item> items]
function Inventory:get_items()
  local items = {}

  for k, v in pairs(self:get_items_ids()) do
    local item_obj = Item.find_instance_by_id(v)

    if item_obj then
      table.insert(items, item_obj)

      local inventory = item_obj.inventory

      if inventory then
        table.Add(items, inventory:get_items())
      end
    end
  end

  return items
end

--- Get item ids that the inventory contains.
-- @return [List<Number> items ids]
function Inventory:get_items_ids()
  local items = {}

  for i = 1, self.height do
    for k = 1, self.width do
      local stack = self.slots[i][k]

      if istable(stack) and !table.IsEmpty(stack) then
        for _, v in pairs(stack) do
          items[v] = true
        end
      end
    end
  end

  return table.GetKeys(items)
end

--- Get the items ids that are located in the specified slot.
-- @param x [Number column of the slot, starting from 1]
-- @param y [Number row of the slot, starting from 1]
-- @return [List<Number> items ids, or nil if the slot is out of the inventory bounds]
function Inventory:get_slot(x, y)
  if x <= self.width and y <= self.height then
    return self.slots[y][x]
  end
end

--- Get the first item id that is located in the specified slot.
-- @param x [Number]
-- @param y [Number]
-- @return [Number instance id, or nil if the slot is empty]
function Inventory:get_first_in_slot(x, y)
  local slot = self:get_slot(x, y)

  if istable(slot) and !table.IsEmpty(slot) then
    return slot[1]
  end
end

--- Get the amount of items by their id.
-- @param id [String]
-- @return [Number]
function Inventory:get_items_count(id)
  return table.Count(self:find_items(id))
end

--- Checks if the inventory is empty.
-- ```
-- if target:get_inventory('main_inventory'):is_empty() then
--   target:notify('Your main inventory is empty!')
-- end
-- ```
-- @return [Boolean]
function Inventory:is_empty()
  return table.IsEmpty(self:get_items_ids())
end

--- Find a specified item object by its id.
-- @param id [String]
-- @return [Item first item found, or nil if there is none]
function Inventory:find_item(id)
  for k, v in pairs(self:get_items()) do
    if v.id == id then
      return v
    end
  end
end

--- Find specified item objects by their id.
-- @param id [String]
-- @return [List<Item> items]
function Inventory:find_items(id)
  local items = {}

  for k, v in pairs(self:get_items()) do
    if v.id == id then
      table.insert(items, v)
    end
  end

  return items
end

--- Check if the inventory contains an item by its id.
-- @param id [String]
-- @return [Boolean, Item found item]
function Inventory:has_item(id)
  local item_obj = self:find_item(id)

  if item_obj then
    return true, item_obj
  end

  return false
end

--- Check if the inventory contains items by their id.
-- @param id [String]
-- @param amount=1 [Number amount of items the inventory has to contain]
-- @return [Boolean, List<Item> found items]
function Inventory:has_items(id, amount)
  amount = amount or 1

  local items = self:find_items(id)

  if table.Count(items) >= amount then
    return true, items
  end

  return false, items
end

--- Check if the inventory contains an item by its instance id.
-- @param instance_id [Number]
-- @return [Boolean, Item found item]
function Inventory:has_item_by_id(instance_id)
  if table.HasValue(self:get_items_ids(), instance_id) then
    return true, Item.find_instance_by_id(instance_id)
  end

  return false
end

--- Find the best position for the item to be placed.
-- @param item_obj [Item]
-- @param w [Number width of the item]
-- @param h [Number height of the item]
-- @return [Number x, Number y, Boolean is a rotation needed]
function Inventory:find_position(item_obj, w, h)
  local x, y, need_rotation

  if item_obj.stackable then
    x, y, need_rotation = self:find_stack(item_obj, w, h)

    if x and y then
      need_rotation = need_rotation != item_obj.rotated
    end
  end

  if !x or !y then
    x, y = self:find_empty_slot(w, h)

    if !x or !y then
      x, y = self:find_empty_slot(h, w)

      need_rotation = true
    end
  end

  return x, y, need_rotation
end

--- Find the stack position for the item.
-- @param item_obj [Item]
-- @param w [Number width of the item]
-- @param h [Number height of the item]
-- @return [Number x, Number y, Boolean is a rotation needed]
function Inventory:find_stack(item_obj, w, h)
  for k, v in pairs(self:find_items(item_obj.id)) do
    if self:can_stack(item_obj, v) then
      return v.x, v.y, v.rotated
    end
  end
end

--- Check if two items may be stacked.
-- @param item_obj [Item]
-- @param stack_item [Item]
-- @return [Boolean]
function Inventory:can_stack(item_obj, stack_item)
  local slot = self:get_slot(stack_item.x, stack_item.y)

  if stack_item and stack_item.id == item_obj.id
  and item_obj.stackable and #slot < item_obj.max_stack then
    return true
  end

  return false
end

--- Find free space in the inventory.
-- @param w [Number]
-- @param h [Number]
-- @return [Number x, Number y]
function Inventory:find_empty_slot(w, h)
  for i = 1, self:get_height() - h + 1 do
    for k = 1, self:get_width() - w + 1 do
      if self:slots_empty(k, i, w, h) then
        return k, i
      end
    end
  end
end

--- Check if the specified slots are empty.
-- @param x [Number]
-- @param y [Number]
-- @param w [Number]
-- @param h [Number]
-- @return [Boolean]
function Inventory:slots_empty(x, y, w, h)
  for i = y, y + h - 1 do
    for k = x, x + w - 1 do
      if !table.IsEmpty(self.slots[i][k]) then
        return false
      end
    end
  end

  return true
end

--- Check if the item overlaps another stackable item and return adjusted data.
-- @param item_obj [Item]
-- @param x [Number]
-- @param y [Number]
-- @param w [Number]
-- @param h [Number]
-- @return [Boolean, Number x, Number y, Boolean is a rotation needed]
function Inventory:overlaps_stack(item_obj, x, y, w, h)
  for i = y, y + h - 1 do
    for k = x, x + w - 1 do
      local slot = self:get_slot(k, i)
      local stack_item = Item.find_instance_by_id(slot[1])

      if stack_item and self:can_stack(item_obj, stack_item) and !table.HasValue(slot, item_obj.instance_id) then
        return true, stack_item.x, stack_item.y, stack_item.rotated != item_obj.rotated
      end
    end
  end
end

--- Check if the item overlaps itself.
-- @param instance_id [Number]
-- @param x [Number]
-- @param y [Number]
-- @param w [Number]
-- @param h [Number]
-- @return [Boolean]
function Inventory:overlaps_itself(instance_id, x, y, w, h)
  for i = y, y + h - 1 do
    for k = x, x + w - 1 do
      local slot = self.slots[i][k]

      if table.HasValue(slot, instance_id) then
        return true
      end
    end
  end

  return false
end

--- Check if the item overlaps only itself.
-- @param instance_id [Number]
-- @param x [Number]
-- @param y [Number]
-- @param w [Number]
-- @param h [Number]
-- @return [Boolean]
function Inventory:overlaps_only_itself(instance_id, x, y, w, h)
  for i = y, y + h - 1 do
    for k = x, x + w - 1 do
      local slot = self.slots[i][k]

      if !table.HasValue(slot, instance_id) and !table.IsEmpty(slot) then
        return false
      end
    end
  end

  return true
end

--- Get the item size based on inventory and item params.
-- @param item_obj [Item]
-- @return [Number width, Number height]
function Inventory:get_item_size(item_obj)
  if !self:is_multislot() then
    return 1, 1
  end

  local item_w, item_h = item_obj.width, item_obj.height

  if item_obj.rotated then
    return item_h, item_w
  else
    return item_w, item_h
  end
end

if SERVER then
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

    if !x or !y or x < 1 or y < 1 or x + w - 1 > self:get_width() or y + h - 1 > self:get_height() then
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

      for i = y, y + h - 1 do
        for k = x, x + w - 1 do
          table.insert(self.slots[i][k], item_obj.instance_id)
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

    for i = 1, amount do
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

  --- Take an item object from the inventory.
  -- @param item_obj [Item]
  -- @return [Boolean was the item taken successfully, String text of the error that occurred]
  function Inventory:take_item_table(item_obj)
    if !item_obj then return false, 'error.inventory.invalid_item' end

    local x, y = item_obj.x, item_obj.y
    local w, h = self:get_item_size(item_obj)

    item_obj.inventory_id = nil
    item_obj.inventory_type = nil
    item_obj.x = nil
    item_obj.y = nil
    item_obj.rotated = false

    for i = y, y + h - 1 do
      for k = x, x + w - 1 do
        table.RemoveByValue(self.slots[i][k], item_obj.instance_id)
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

    for i = 1, amount do
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
    -- is in. The Inventory plugin uses it to ask the `can_move` callback of the item and to
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

    if !x or !y or x < 1 or y < 1 or x + w - 1 > self:get_width() or y + h - 1 > self:get_height() then
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

    for i = old_y, old_y + old_h - 1 do
      for k = old_x, old_x + old_w - 1 do
        table.RemoveByValue(self.slots[i][k], instance_id)
      end
    end

    for i = y, y + h - 1 do
      for k = x, x + w - 1 do
        table.insert(self.slots[i][k], instance_id)
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
    -- The Inventory plugin also runs it, without a target slot, before a player picks an
    -- item up from the world into one of their inventories. The Inventory plugin uses it
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

    if !x or !y or x < 1 or y < 1 or x + w - 1 > inventory:get_width() or y + h - 1 > inventory:get_height() then
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
    -- Besides a transfer between two inventories, as here, the Inventory plugin runs it
    -- when a player picks an item up from the world (without `old_inventory`, and only
    -- if the item fits) and when an item is dropped or removed after
    -- use (with nil as `new_inventory`). The Inventory plugin uses it to call the
    -- `on_transfer` callback of the item, which is how equipable items get equipped and
    -- unequipped.
    -- @param item_obj [Item The item that is about to be moved]
    -- @param new_inventory [Inventory The inventory the item goes to, or nil if it leaves
    --   for the world or is removed]
    -- @param old_inventory [Inventory The inventory the item is in, or nil if it comes from
    --   the world]
    hook.Run('PreItemTransfer', item_obj, inventory, self)

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

    for i = old_y, old_y + old_h - 1 do
      for k = old_x, old_x + old_w - 1 do
        table.RemoveByValue(self.slots[i][k], instance_id)
      end
    end

    for i = y, y + h - 1 do
      for k = x, x + w - 1 do
        table.insert(inventory.slots[i][k], instance_id)
      end
    end

    self:check_size()
    inventory:check_size()

    --- Called on the server right after an item has changed its inventory. It is run in
    -- the same cases as `PreItemTransfer`: a transfer between two inventories, as here, a
    -- pickup from the world (without `old_inventory`, and only if the item did fit) and a
    -- drop or a removal after use (with nil as `new_inventory`).
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

    for k, v in ipairs(instance_ids) do
      local success, error_text = self:move_item(v, x, y, was_rotated)

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
    for k, v in ipairs(instance_ids) do
      local success, error_text = self:transfer_item(v, inventory, x, y, was_rotated)

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
    if self:has_receiver(receiver) then return end

    table.insert(self.receivers, receiver)
  end

  --- Remove the receiver from the inventory.
  -- @param receiver [Player]
  function Inventory:remove_receiver(receiver)
    table.RemoveByValue(self.receivers, receiver)
  end

  --- Checks if the player currently receives the inventory data, which is the case for
  -- their own inventories and for the inventories that have been opened for them.
  -- @param receiver [Player]
  -- @return [Boolean]
  function Inventory:has_receiver(receiver)
    return table.HasValue(self.receivers, receiver)
  end

  --- Checks whether a player is entitled to have the inventory open. The owner always is.
  -- The inside of a container item is for whoever carries the item, or stands within reach
  -- of it while it lies in the world. Any other inventory that belongs to an entity is for
  -- those within reach of that entity, and an inventory without an owner is for anyone.
  -- The server closes an inventory for the receivers that fail this check.
  -- @param receiver [Player]
  -- @return [Boolean]
  -- @see [Inventories.is_in_reach]
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
        return Inventories.is_in_reach(receiver, item_obj.entity)
      end

      return receiver:has_item_by_id(self.instance_id)
    end

    if owner != nil then
      return Inventories.is_in_reach(receiver, owner)
    end

    return true
  end

  --- Send inventory data to its receivers.
  function Inventory:sync()
    for k, v in pairs(self:get_receivers()) do
      if IsValid(v) then
        for k1, v1 in pairs(self:get_items_ids()) do
          Item.network_item(v, v1)
        end

        Cable.send(v, 'fl_inventory_sync', self:to_networkable())
      else
        self:remove_receiver(v)
      end
    end
  end

  --- @warning [Internal]
  -- Check the size of the inventory and resize it if needed.
  function Inventory:check_size()
    if !self:is_height_infinite() and !self:is_width_infinite() then return end

    local max_x, max_y = 0, 0

    for i = 1, self:get_height() do
      for k = 1, self:get_width() do
        if !table.IsEmpty(self:get_slot(k, i)) then
          max_x, max_y = math.max(max_x, k), i
        end
      end
    end

    if self:is_height_infinite() then
      self.height = max_y + 1
    end

    if self:is_width_infinite() then
      self.width = max_x + 1
    end

    self:rebuild()
    self:sync()
  end

  --- @warning [Internal]
  -- Fill the inventory with certain items by their ids.
  -- @param items_ids [List<Number> instance ids]
  function Inventory:load_items(items_ids)
    for k, v in pairs(items_ids) do
      local item_obj = Item.find_instance_by_id(v)

      if item_obj then
        local x, y = item_obj.x, item_obj.y

        self:add_item(item_obj, x, y)
      end
    end
  end

  --- Disables the inventory, preventing the manipulation of items inside it.
  -- @param disabled [Boolean]
  function Inventory:set_disabled(disabled)
    self.disabled = disabled

    self:sync()
  end
else
  --- Creates a panel for the inventory.
  -- It will update automatically every time
  -- the inventory synchronizes itself.
  -- ```
  -- local hotbar = PLAYER:get_inventory('hotbar'):create_panel()
  -- hotbar:set_slot_size(math.scale(80))
  -- hotbar:set_slot_padding(math.scale(8))
  -- hotbar:SizeToContents()
  -- hotbar:rebuild()
  -- ```
  -- @param parent=nil [Panel]
  -- @return [Panel]
  function Inventory:create_panel(parent)
    local panel = vgui.Create('fl_inventory', parent)
    panel:set_title(t(self.title or self.type))
    panel:set_icon(self.icon)
    panel:set_inventory_id(self.id)
    panel:rebuild()

    self.panel = panel

    return panel
  end
end
