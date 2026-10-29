--- Server-side receivers of the Items plugin for inventories: the move, drop and close
-- requests of the inventory panels, handled once they have been checked.

local function can_handle_items(actor)
  if !actor:Alive() then
    return false
  end

  return !isfunction(actor.is_ragdolled) or !actor:is_ragdolled()
end

--- Checks the item list of a move or drop request. The list has to name distinct items
-- that all are in one inventory, and that inventory has to be open for the player and one
-- they are still entitled to.
-- @param actor [Player the player who sent the request]
-- @param instance_ids [Any the list of instance ids as received from the client]
-- @return [Inventory the inventory the items are in, List<Number> the instance ids as a
--   clean list; nothing if the request is not valid]
-- @see [Inventory#can_be_viewed_by]
local function find_requested_stack(actor, instance_ids)
  if !istable(instance_ids) then return end

  local first_item = Item.find_instance_by_id(instance_ids[1])
  local inventory = first_item and Inventories.find(first_item.inventory_id)

  if !inventory or !inventory:has_receiver(actor) or !inventory:can_be_viewed_by(actor) then return end

  local stack = {}
  local listed = {}
  local find_instance_by_id = Item.find_instance_by_id

  for index, instance_id in ipairs(instance_ids) do
    local stack_item = find_instance_by_id(instance_id)

    if !stack_item or stack_item.inventory_id != inventory.id or listed[instance_id]
    or !inventory:has_item_by_id(instance_id) then
      return
    end

    listed[instance_id] = true
    stack[index] = instance_id
  end

  return inventory, stack
end

Cable.receive('fl_item_move', function(actor, instance_ids, inventory_id, x, y, was_rotated)
  local old_inventory, stack = find_requested_stack(actor, instance_ids)
  local inventory = Inventories.find(inventory_id)

  if !old_inventory or !inventory then return end
  if !inventory:has_receiver(actor) or !inventory:can_be_viewed_by(actor) then return end
  if !isnumber(x) or !isnumber(y) or x != x or y != y then return end

  if !can_handle_items(actor) then
    old_inventory:sync()
    inventory:sync()

    return
  end

  instance_ids = stack
  x, y = math.floor(x), math.floor(y)
  was_rotated = was_rotated == true

  local instance_id = instance_ids[1]
  local item_obj = Item.find_instance_by_id(instance_id)

  --- Called on the server when a player asks to move items to an inventory slot by
  -- dragging them, before anything is moved. The target can be the inventory the items
  -- are in or another one. Requests that name items or inventories that do not exist,
  -- the same item twice, items from more than one inventory, an inventory that is not
  -- open for the player or that they are no longer entitled to, or a slot that is not a
  -- number are dropped before the hook is run, and so are the requests of a player who
  -- is dead or lies on the ground as a ragdoll.
  -- @param actor [Player The player moving the items]
  -- @param item_obj [Item The first of the items that are being moved]
  -- @param instance_ids [List<Number> Instance ids of the items: one item, or several
  --   from the same stack]
  -- @param inventory_id [Number Id of the inventory the items are being moved to]
  -- @param x [Number Column of the target slot]
  -- @param y [Number Row of the target slot]
  -- @return [Boolean Return false to prevent the move]
  if hook.Run('PlayerCanMoveItem', actor, item_obj, instance_ids, inventory_id, x, y) == false then
    return
  end

  local success

  if inventory_id == item_obj.inventory_id then
    success = inventory:move_stack(instance_ids, x, y, was_rotated)
  else
    if #instance_ids == 1 then
      success = old_inventory:transfer_item(instance_id, inventory, x, y, was_rotated)
    else
      success = old_inventory:transfer_stack(instance_ids, inventory, x, y, was_rotated)
    end

    old_inventory:sync()
  end

  inventory:sync()

  if !success then return end

  --- Called on the server after a player has moved items to an inventory slot by dragging
  -- them and the inventories have been synchronized. It is not run when the items could
  -- not be moved or when `PlayerCanMoveItem` has prevented the move.
  -- @param actor [Player The player who moved the items]
  -- @param item_obj [Item The first of the items]
  -- @param instance_ids [List<Number> Instance ids of the items]
  -- @param inventory_id [Number Id of the inventory the items were moved to]
  -- @param x [Number Column of the target slot]
  -- @param y [Number Row of the target slot]
  hook.Run('OnItemMoved', actor, item_obj, instance_ids, inventory_id, x, y)
end)

Cable.receive('fl_item_drop', function(actor, instance_ids)
  local inventory, stack = find_requested_stack(actor, instance_ids)

  if !inventory then return end

  if !can_handle_items(actor) then
    inventory:sync()

    return
  end

  --- Called on the server when a player drops items by dragging them out of an
  -- inventory panel. The hook is what performs the drop: the Items plugin handles it
  -- by taking the items out of their inventory and spawning them in front of the player.
  -- Requests that name items that do not exist, the same item twice, items from more
  -- than one inventory, or an inventory that is not open for the player or that they are
  -- no longer entitled to are dropped before the hook is run, and so are the requests of
  -- a player who is dead or lies on the ground as a ragdoll. The Items plugin runs the
  -- same hook with a single instance id instead of a list when a player uses the drop
  -- option of an item's menu, so a handler has to accept both.
  -- @param actor [Player The player dropping the items]
  -- @param instance_ids [List<Number> Instance ids of the items, all from one inventory]
  hook.Run('PlayerDropItem', actor, stack)
end)

Cable.receive('fl_inventory_close', function(actor, inventory_ids)
  if !istable(inventory_ids) then return end

  local closed_inventory

  for _, inventory_id in pairs(inventory_ids) do
    local inventory = Inventories.find(inventory_id)

    if inventory and inventory.owner != actor and inventory:has_receiver(actor) then
      inventory:remove_receiver(actor)
      inventory:sync()

      closed_inventory = closed_inventory or inventory
    end
  end

  if !closed_inventory then return end

  --- Called on the server when a player has closed the inventories that were opened for
  -- them, such as a container or the inventories of another player. The player has been
  -- removed from the receivers of every closed inventory by now. The hook is run once
  -- per request, with the first of the closed inventories; the player's own inventories
  -- and inventories that do not exist or were not open for the player are skipped, and the
  -- hook is not run when none is left.
  -- `Player:close_inventories` runs the same hook when the server closes inventories for
  -- a player, which it does by itself once the player is no longer entitled to them.
  -- @param actor [Player The player who closed the inventories]
  -- @param inventory [Inventory The first of the inventories that were closed]
  hook.Run('OnInventoryClosed', actor, closed_inventory)
end)
