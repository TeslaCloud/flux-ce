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
-- `CanItemMove`, `CanItemTransfer`, `PreItemTransfer` and `ItemTransferred` hooks.
-- `Inventory:release_item` takes an item out for good between the last two hooks, to be
-- dropped into the world, and `Inventory:destroy_item` also synchronizes the inventory and
-- removes the item. The changes reach the clients when `Inventory:sync` is called, which
-- sends the contents of the inventory to the players listed as its receivers. On the
-- client an inventory is a copy of what was last synchronized, and `Inventory:create_panel`
-- displays it.
--
-- Other fields: `owner` is the player or entity the inventory belongs to, and
-- `instance_id` is the instance id of the container item it is the inside of. On the
-- server, `default` marks the inventory of a player that items go to when none is named,
-- and `infinite_width` and `infinite_height` make the inventory resize itself to keep
-- an empty column or row past its last item.
--
-- What an inventory holds is saved to the database as held by the holder of the
-- inventory: the character in its `character_id` field, the container item in its
-- `instance_id` field or the container prop in its `container_id` field. Putting an item
-- into an inventory makes the inventory its holder (`Item.set_holder`), and taking it out
-- leaves it without one. An inventory that has none of these fields holds items without
-- saving them, and they keep the place they were last saved in.

local pairs = pairs
local next = next
local istable = istable
local math_max = math.max
local math_min = math.min
local table_has_value = table.HasValue

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
  local slots = self.slots
  local width = self.width

  for i = 1, self.height do
    local row = slots[i] or {}

    slots[i] = row

    for k = 1, width do
      row[k] = row[k] or {}
    end
  end
end

--- Get item objects that the inventory contains.
-- Also includes items from the containers.
-- @return [List<Item> items]
function Inventory:get_items()
  local items = {}
  local ids = self:get_items_ids()
  local find_instance_by_id = Item.find_instance_by_id

  for i = 1, #ids do
    local item_obj = find_instance_by_id(ids[i])

    if item_obj then
      items[#items + 1] = item_obj

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
  local slots = self.slots
  local width = self.width

  for i = 1, self.height do
    local row = slots[i]

    for k = 1, width do
      local stack = row[k]

      if istable(stack) then
        for _, instance_id in pairs(stack) do
          items[instance_id] = true
        end
      end
    end
  end

  local ids = {}

  for instance_id in pairs(items) do
    ids[#ids + 1] = instance_id
  end

  return ids
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

  if istable(slot) and next(slot) != nil then
    return slot[1]
  end
end

--- Get the amount of items by their id.
-- @param id [String]
-- @return [Number]
function Inventory:get_items_count(id)
  return #self:find_items(id)
end

--- Checks if the inventory is empty.
-- ```
-- if target:get_inventory('main_inventory'):is_empty() then
--   target:notify('Your main inventory is empty!')
-- end
-- ```
-- @return [Boolean]
function Inventory:is_empty()
  local slots = self.slots
  local width = self.width

  for i = 1, self.height do
    local row = slots[i]

    for k = 1, width do
      local stack = row[k]

      if istable(stack) and next(stack) != nil then
        return false
      end
    end
  end

  return true
end

--- Find a specified item object by its id.
-- @param id [String]
-- @return [Item first item found, or nil if there is none]
function Inventory:find_item(id)
  local items = self:get_items()

  for i = 1, #items do
    local item_obj = items[i]

    if item_obj.id == id then
      return item_obj
    end
  end
end

--- Find specified item objects by their id.
-- @param id [String]
-- @return [List<Item> items]
function Inventory:find_items(id)
  local items = {}
  local all_items = self:get_items()

  for i = 1, #all_items do
    local item_obj = all_items[i]

    if item_obj.id == id then
      items[#items + 1] = item_obj
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

  if #items >= amount then
    return true, items
  end

  return false, items
end

--- Check if the inventory contains an item by its instance id.
-- @param instance_id [Number]
-- @return [Boolean, Item found item]
function Inventory:has_item_by_id(instance_id)
  local slots = self.slots
  local width = self.width

  for i = 1, self.height do
    local row = slots[i]

    for k = 1, width do
      local stack = row[k]

      if istable(stack) and table_has_value(stack, instance_id) then
        return true, Item.find_instance_by_id(instance_id)
      end
    end
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
-- @param _w [Number width of the item]
-- @param _h [Number height of the item]
-- @return [Number x, Number y, Boolean is a rotation needed]
function Inventory:find_stack(item_obj, _w, _h)
  local items = self:find_items(item_obj.id)

  for i = 1, #items do
    local stack_item = items[i]

    if self:can_stack(item_obj, stack_item) then
      return stack_item.x, stack_item.y, stack_item.rotated
    end
  end
end

--- Check if an item may be put onto the stack of another item of the inventory.
-- @param item_obj [Item]
-- @param stack_item [Item an item in this inventory; items elsewhere never take a stack]
-- @return [Boolean]
function Inventory:can_stack(item_obj, stack_item)
  if !stack_item or stack_item.inventory_id != self.id
  or stack_item.id != item_obj.id or !item_obj.stackable then
    return false
  end

  local slot = self:get_slot(stack_item.x, stack_item.y)

  return istable(slot) and #slot < item_obj.max_stack
end

--- Find free space in the inventory.
-- @param w [Number]
-- @param h [Number]
-- @return [Number x, Number y]
function Inventory:find_empty_slot(w, h)
  local max_x = self.width - w + 1

  for i = 1, self.height - h + 1 do
    for k = 1, max_x do
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
  local slots = self.slots
  local max_x = x + w - 1

  for i = y, y + h - 1 do
    local row = slots[i]

    for k = x, max_x do
      if next(row[k]) != nil then
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
  local find_instance_by_id = Item.find_instance_by_id
  local instance_id = item_obj.instance_id
  local max_x = x + w - 1

  for i = y, y + h - 1 do
    for k = x, max_x do
      local slot = self:get_slot(k, i)
      local stack_item = find_instance_by_id(slot[1])

      if stack_item and self:can_stack(item_obj, stack_item) and !table_has_value(slot, instance_id) then
        return true, stack_item.x, stack_item.y, stack_item.rotated != item_obj.rotated
      end
    end
  end
end

--- Check if the item overlaps itself. The part of the area that lies outside of the
-- inventory is ignored, so the position does not have to be within its bounds.
-- @param instance_id [Number]
-- @param x [Number]
-- @param y [Number]
-- @param w [Number]
-- @param h [Number]
-- @return [Boolean]
function Inventory:overlaps_itself(instance_id, x, y, w, h)
  local slots = self.slots
  local min_x, max_x = math_max(x, 1), math_min(x + w - 1, self.width)

  for i = math_max(y, 1), math_min(y + h - 1, self.height) do
    local row = slots[i]

    for k = min_x, max_x do
      if table_has_value(row[k], instance_id) then
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
  local slots = self.slots
  local max_x = x + w - 1

  for i = y, y + h - 1 do
    local row = slots[i]

    for k = x, max_x do
      local slot = row[k]

      if next(slot) != nil and !table_has_value(slot, instance_id) then
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
  if !self.multislot then
    return 1, 1
  end

  local item_w, item_h = item_obj.width, item_obj.height

  if item_obj.rotated then
    return item_h, item_w
  else
    return item_w, item_h
  end
end

if CLIENT then
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
