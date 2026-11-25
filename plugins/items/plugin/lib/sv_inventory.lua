--- Server side of the Inventories library: `Inventories.place_items`, which puts the items
-- loaded from the database into the inventories that hold them, `Inventories.find_by_item`,
-- which finds the inventory an item is in, and `Inventories.remove`, which takes
-- inventories out of use.

local IsValid = IsValid

--- Finds the inventory that has an item in one of its slots: the registered inventory that
-- the `inventory_id` field of the item names, if the item is in its slots. Server-side only.
-- @param item_obj [Item]
-- @return [Inventory, or nil if the item is in no inventory]
function Inventories.find_by_item(item_obj)
  local inventory = Inventories.stored[item_obj.inventory_id]

  if inventory and inventory:has_item_by_id(item_obj.instance_id) then
    return inventory
  end
end

--- Closes inventories for every player they are open for, other than their owner, and
-- unregisters them, so that nothing reaches them anymore. Each of those players gets the
-- `InventoryClosed` hook once for all of the inventories. Server-side only.
-- @param inventories [List<Inventory>]
-- @see [Player#close_inventories]
function Inventories.remove(inventories)
  local viewers = {}

  for _, inventory in ipairs(inventories) do
    for _, receiver in ipairs(inventory.receivers) do
      if IsValid(receiver) and receiver != inventory.owner then
        viewers[receiver] = true
      end
    end
  end

  for receiver in pairs(viewers) do
    receiver:close_inventories(inventories)
  end

  local stored = Inventories.stored

  for _, inventory in ipairs(inventories) do
    if stored[inventory.id] == inventory then
      stored[inventory.id] = nil
    end
  end
end

--- Finds the inventory a loaded item goes to, along with the slot it was saved in. An
-- infinite inventory of the player is widened or heightened to reach the slot.
-- @param item_obj [Item]
-- @param owner=nil [Player]
-- @return [Inventory, nil if there is none to put the item into or false if the item belongs
--   elsewhere; Number x, Number y]
local function find_target(item_obj, owner)
  if item_obj.parent_id then
    local container = Item.find_instance_by_id(item_obj.parent_id)

    if !container or !container.create_inventory then return end

    if !container.inventory then
      container:create_inventory()
    end

    return container.inventory, item_obj.x, item_obj.y
  end

  if !item_obj.character_id or !IsValid(owner) then return false end

  local x, y = item_obj.x, item_obj.y
  local inventory = owner:get_inventories()[item_obj.inventory_type]

  if !inventory or !x or !y then
    return owner:get_inventories()[owner.default_inventory or 'main_inventory']
  end

  if inventory:is_width_infinite() and x > inventory:get_width() then
    inventory:set_width(x + 1)
  end

  if inventory:is_height_infinite() and y > inventory:get_height() then
    inventory:set_height(y + 1)
  end

  return inventory, x, y
end

--- Puts items that have been loaded from the database where they belong: items inside
-- of a container item into the inventory of the container item, which is created if
-- needed, and items of a character into the inventory of the player of the type they
-- were saved in, or into the default inventory if the player has no such inventory.
-- The items whose saved slot lies inside of their inventory are placed first, so that the
-- others, which get the best free slot, do not take a slot that an item has been saved in.
-- Items that already are in an inventory and items that belong elsewhere are skipped.
-- Server-side only.
-- @param items [List<Item>]
-- @param owner=nil [Player the player whose character the items belong to]
-- @return [List<Item> the items that did not fit anywhere]
function Inventories.place_items(items, owner)
  local unplaced = {}
  local deferred = {}

  for _, item_obj in ipairs(items) do
    if !item_obj.inventory_id then
      local inventory, x, y = find_target(item_obj, owner)

      if inventory then
        local w, h = inventory:get_item_size(item_obj)

        if !inventory:fits_in_bounds(x, y, w, h) then
          deferred[#deferred + 1] = { item_obj, inventory }
        elseif !inventory:add_item(item_obj, x, y) then
          unplaced[#unplaced + 1] = item_obj
        end
      elseif inventory == nil then
        unplaced[#unplaced + 1] = item_obj
      end
    end
  end

  for _, entry in ipairs(deferred) do
    local item_obj = entry[1]

    if !entry[2]:add_item(item_obj) then
      unplaced[#unplaced + 1] = item_obj
    end
  end

  return unplaced
end
