--- Server side of the Inventories library: `Inventories.place_items`, which puts the items
-- loaded from the database into the inventories that hold them, `Inventories.find_by_item`,
-- which finds the inventory an item is in, `Inventories.remove`, which takes inventories
-- out of use, and `Inventories.run_closed_hooks`, which tells plugins that inventories have
-- been closed for a player.

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

--- Runs the `InventoryClosed` hook for inventories that have been closed for a player: once
-- for every holder among them, with the first of its inventories. The holder of an
-- inventory is the entity that owns it, such as a player or a container prop, or the
-- inventory itself when it has no owner, such as the inventory of a container item.
-- Server-side only.
-- @param actor [Player the player the inventories have been closed for]
-- @param inventories [List<Inventory> the closed inventories, in the order they were closed]
function Inventories.run_closed_hooks(actor, inventories)
  local holders = {}

  for _, inventory in ipairs(inventories) do
    local holder = inventory.owner or inventory

    if !holders[holder] then
      holders[holder] = true

      --- Called on the server when inventories that were opened for a player have been
      -- closed: by the player, such as a container or the inventories of another player,
      -- or by the server, when the player may not view them anymore or the inventories
      -- are removed. The player is not among the receivers of the closed inventories at
      -- this point. The hook is run once for every entity that owns closed
      -- inventories, and once for every closed inventory that has no owner, such as the
      -- inventory of a container item; the player's own inventories and inventories that
      -- were not open for the player are never passed.
      -- @param actor [Player The player the inventories have been closed for]
      -- @param inventory [Inventory The first closed inventory of its owner]
      hook.Run('InventoryClosed', actor, inventory)
    end
  end
end

--- Closes inventories for every player they are open for, other than their owner, and
-- unregisters them, so that nothing reaches them anymore. The clients of those players
-- forget their copies of them. Each of those players gets the `InventoryClosed` hook once
-- for every owner of the inventories. Server-side only.
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
    receiver:close_inventories(inventories, true)
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
-- Items that already are in the slots of a registered inventory and items that belong
-- elsewhere are skipped. Server-side only.
-- @param items [List<Item>]
-- @param owner=nil [Player the player whose character the items belong to]
-- @return [List<Item> the items that did not fit anywhere]
function Inventories.place_items(items, owner)
  local unplaced = {}
  local deferred = {}

  for _, item_obj in ipairs(items) do
    if !Inventories.find_by_item(item_obj) then
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
