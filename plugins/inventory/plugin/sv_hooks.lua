--- Server side of the Inventory plugin: creates the default inventories of players, saves
-- where items are, does what the take, use and drop actions of items are supposed to do,
-- enforces the rules of moving items between inventories, closes the inventories that
-- players are no longer entitled to, and handles the move, drop and close requests of the
-- clients.

local pairs = pairs
local IsValid = IsValid

local drop_near_distance_sqr = 80 * 80

--- Checks the item list of a move or drop request. The list has to name distinct items
-- that all are in one inventory, and that inventory has to be open for the player.
-- @param actor [Player the player who sent the request]
-- @param instance_ids [Any the list of instance ids as received from the client]
-- @return [Inventory the inventory the items are in, List<Number> the instance ids as a
--   clean list; nothing if the request is not valid]
local function find_requested_stack(actor, instance_ids)
  if !istable(instance_ids) then return end

  local first_item = Item.find_instance_by_id(instance_ids[1])
  local inventory = first_item and Inventories.find(first_item.inventory_id)

  if !inventory or !inventory:has_receiver(actor) then return end

  local stack = {}
  local listed = {}
  local find_instance_by_id = Item.find_instance_by_id

  for k, v in ipairs(instance_ids) do
    local stack_item = find_instance_by_id(v)

    if !stack_item or stack_item.inventory_id != inventory.id or listed[v] then return end

    listed[v] = true
    stack[k] = v
  end

  return inventory, stack
end

--- Calls the 'AddDefaultItems' plugin hook for a character that has just been created.
-- @param owner [Player]
-- @param char [Character]
-- @param char_data [Map data the character was created from]
function Inventories:PostCreateCharacter(owner, char, char_data)
  --- Called on the server when a character has just been created, before it is saved
  -- for the first time, so that plugins can give it its starting items. It is run with
  -- `Plugin.call`, so gamemode functions do not receive it.
  -- @param owner [Player The player who created the character]
  -- @param char [Character The new character]
  Plugin.call('AddDefaultItems', owner, char)
end

--- Deletes inventories of the disconnected player from the server cache.
-- @param actor [Player]
function Inventories:PlayerDisconnected(actor)
  actor:delete_inventories()
end

--- Recreates inventories of the player when their active character changes.
-- @param owner [Player]
-- @param character [Character]
function Inventories:OnActiveCharacterSet(owner, character)
  owner:delete_inventories()
  owner:create_inventories()
end

--- Creates the default set of the player's inventories:
-- main inventory, hotbar, pockets and the equipment slots.
-- @param owner [Player]
-- @param inventories [Map table to put the new inventories into, keyed by inventory type]
function Inventories:CreatePlayerInventories(owner, inventories)
  local main_inventory = Inventory.new()
    main_inventory.title = 'ui.inventory.main_inventory'
    main_inventory:set_size(Config.get('inventory_width'), Config.get('inventory_height'))
    main_inventory.type = 'main_inventory'
    main_inventory.default = true
  inventories[main_inventory.type] = main_inventory

  local hotbar = Inventory.new()
    hotbar.title = 'ui.inventory.hotbar'
    hotbar:set_size(Config.get('hotbar_width'), Config.get('hotbar_height'))
    hotbar.type = 'hotbar'
    hotbar.multislot = false
  inventories[hotbar.type] = hotbar

  local equipment_helmet = Inventory.new()
    equipment_helmet.title = 'ui.inventory.equipment.helmet'
    equipment_helmet.icon = 'flux/icons/helmet.png'
    equipment_helmet:set_size(1, 1)
    equipment_helmet.type = 'equipment_helmet'
    equipment_helmet.multislot = false
  inventories[equipment_helmet.type] = equipment_helmet

  local equipment_mask = Inventory.new()
    equipment_mask.title = 'ui.inventory.equipment.mask'
    equipment_mask.icon = 'flux/icons/gas-mask.png'
    equipment_mask:set_size(1, 1)
    equipment_mask.type = 'equipment_mask'
    equipment_mask.multislot = false
  inventories[equipment_mask.type] = equipment_mask

  local equipment_torso = Inventory.new()
    equipment_torso.title = 'ui.inventory.equipment.torso'
    equipment_torso.icon = 'flux/icons/t-shirt.png'
    equipment_torso:set_size(1, 1)
    equipment_torso.type = 'equipment_torso'
    equipment_torso.multislot = false
  inventories[equipment_torso.type] = equipment_torso

  local equipment_hands = Inventory.new()
    equipment_hands.title = 'ui.inventory.equipment.hands'
    equipment_hands.icon = 'flux/icons/gloves.png'
    equipment_hands:set_size(1, 1)
    equipment_hands.type = 'equipment_hands'
    equipment_hands.multislot = false
  inventories[equipment_hands.type] = equipment_hands

  local equipment_legs = Inventory.new()
    equipment_legs.title = 'ui.inventory.equipment.legs'
    equipment_legs.icon = 'flux/icons/trousers.png'
    equipment_legs:set_size(1, 1)
    equipment_legs.type = 'equipment_legs'
    equipment_legs.multislot = false
  inventories[equipment_legs.type] = equipment_legs

  local equipment_back = Inventory.new()
    equipment_back.title = 'ui.inventory.equipment.accessories'
    equipment_back.icon = 'flux/icons/light-backpack.png'
    equipment_back:set_size(1, 1)
    equipment_back.type = 'equipment_back'
    equipment_back.multislot = false
  inventories[equipment_back.type] = equipment_back

  local equipment_accessories = Inventory.new()
    equipment_accessories.title = 'ui.inventory.equipment.accessories'
    equipment_accessories.icon = 'flux/icons/cube.png'
    equipment_accessories:set_size(1, 4)
    equipment_accessories.type = 'equipment_accessories'
    equipment_accessories.multislot = false
  inventories[equipment_accessories.type] = equipment_accessories

  local pockets = Inventory.new()
    pockets.title = 'ui.inventory.pockets'
    pockets:set_size(1, Config.get('pockets_height'))
    pockets.type = 'pockets'
    pockets.infinite_width = true
    pockets.multislot = false
  inventories[pockets.type] = pockets
end

--- Stores the instance ids of the player's items in the character,
-- as a comma-separated string.
-- @param owner [Player]
-- @param char [Character]
function Inventories:SaveCharacterData(owner, char)
  if owner:get_character_id() == char.id then
    char.item_ids = table.concat(owner:get_items_ids(), ',')
  end
end

--- Adds the position of the item in its inventory, its rotation and,
-- for containers, the instance ids of the contained items to the saved fields.
-- @param item_obj [Item]
-- @param save_table [Map fields of the item that are going to be saved]
function Inventories:PreItemSave(item_obj, save_table)
  save_table.x = item_obj.x
  save_table.y = item_obj.y
  save_table.inventory_type = item_obj.inventory_type
  save_table.inventory_id = item_obj.inventory_id
  save_table.rotated = item_obj.rotated

  if item_obj.inventory then
    save_table.items = item_obj.inventory:get_items_ids()
  end
end

--- Puts an item lying in the world into one of the player's inventories
-- and removes its entity. Nothing happens if the player has no inventory of the requested
-- type; the player is notified if the 'CanItemTransfer' hook refuses the inventory or the
-- item does not fit.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param ... [Vararg optional hashes; an inv_type field in one of them sets the inventory type]
function Inventories:PlayerTakeItem(actor, item_obj, ...)
  if IsValid(item_obj.entity) then
    local inv_type

    for k, v in pairs({ ... }) do
      if istable(v) then
        for k1, v1 in pairs(v) do
          if k1 == 'inv_type' then
            inv_type = v1
          end
        end
      end
    end

    inv_type = inv_type or item_obj.preferred_inventory or actor.default_inventory

    local player_inventory = actor:get_inventories()[inv_type]

    if !player_inventory then return end

    local can_transfer, transfer_error = hook.Run('CanItemTransfer', item_obj, player_inventory)

    if can_transfer == false then
      if transfer_error then
        actor:notify(transfer_error)
      end

      return
    end

    local w, h = player_inventory:get_item_size(item_obj)

    if !player_inventory:find_position(item_obj, w, h) then
      actor:notify('error.inventory.no_space')

      return
    end

    hook.Run('PreItemTransfer', item_obj, player_inventory)

    local success, error_text = actor:add_item(item_obj, inv_type)

    if success then
      actor:sync_inventories()
      item_obj.entity:Remove()
      Item.async_save_entities()

      hook.Run('ItemTransferred', item_obj, player_inventory)
    else
      actor:notify(error_text)
    end
  end
end

--- Takes the items out of their inventory and spawns them in front of the player. Does
-- nothing if the first item does not exist or is not in an inventory.
-- @param actor [Player]
-- @param instance_ids [Number/List<Number> instance id(s) of items from the same inventory]
function Inventories:PlayerDropItem(actor, instance_ids)
  if isnumber(instance_ids) then
    instance_ids = { instance_ids }
  end

  local trace = actor:GetEyeTraceNoCursor()
  local first_item = Item.find_instance_by_id(table.first(instance_ids))
  local inventory = first_item and Inventories.find(first_item.inventory_id)

  if !inventory then return end

  local drop_near = trace.HitPos:DistToSqr(actor:GetPos()) < drop_near_distance_sqr

  for k, v in pairs(instance_ids) do
    local item_obj = Item.find_instance_by_id(v)

    --- Called on the server before a player drops an item from an inventory into the
    -- world, once for every item of a dropped stack. The Items plugin uses it to ask the
    -- `on_drop` callback of the item.
    -- @param actor [Player The player dropping the item]
    -- @param item_obj [Item The item that is about to be dropped]
    -- @return [Boolean Return false to prevent the drop; the items of the stack that
    --   come after this one are not dropped either]
    if hook.Run('CanPlayerDropItem', actor, item_obj) == false then break end

    hook.Run('PreItemTransfer', item_obj, nil, inventory)

    inventory:take_item_by_id(v)

    hook.Run('ItemTransferred', item_obj, nil, inventory)

    if drop_near then
      Item.spawn(trace.HitPos + Vector(0, 0, 5) * k, Angle(0, 0, 0), item_obj, actor)
    else
      local ent = Item.spawn(actor:EyePos() + trace.Normal * 20 + VectorRand() * 5, Angle(0, 0, 0), item_obj, actor)
      local phys_obj = ent:GetPhysicsObject()

      if IsValid(phys_obj) then
        phys_obj:ApplyForceCenter(trace.Normal * 200)
      end
    end
  end

  inventory:sync()
  Item.async_save_entities()
end

--- Synchronizes the inventory of an item after a menu action has been performed on it.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param act [String name of the menu action]
-- @param ... [Vararg extra arguments of the action]
function Inventories:PlayerUsedItem(actor, item_obj, act, ...)
  local inventory_id = item_obj.inventory_id

  if inventory_id then
    local inventory = Inventories.find(inventory_id)

    if inventory then
      inventory:sync()
    end
  end
end

--- Calls the on_transfer callback of the item before it changes its inventory.
-- @param item_obj [Item]
-- @param new_inventory [Inventory where the item goes, or nil if it is dropped or used up]
-- @param old_inventory [Inventory where the item was, or nil if it is picked up]
function Inventories:PreItemTransfer(item_obj, new_inventory, old_inventory)
  if item_obj.on_transfer then
    item_obj:on_transfer(new_inventory, old_inventory)
  end
end

--- Closes the inventory of a transferred container item
-- for the players who were viewing it and do not have the container anymore.
-- @param item_obj [Item]
-- @param new_inventory [Inventory where the item went, or nil if it was dropped or used up]
-- @param old_inventory [Inventory where the item was, or nil if it was picked up]
function Inventories:ItemTransferred(item_obj, new_inventory, old_inventory)
  local inventory = item_obj.inventory

  if inventory then
    local receivers = inventory.receivers

    for i = #receivers, 1, -1 do
      local receiver = receivers[i]

      if IsValid(receiver) and !receiver:has_item_by_id(item_obj.instance_id) then
        receiver:close_inventory(inventory)
      end
    end
  end
end

--- Closes, once a second, every inventory for the receivers who are no longer entitled to
-- it, so that staying a receiver does not depend on the client reporting that it has closed
-- the window. The inventories that one entity owns are closed for a receiver together, so
-- that the 'OnInventoryClosed' hook runs once when, for example, a player walks away from
-- another player whose inventories they were viewing.
-- @see [Inventory#can_be_viewed_by]
-- @see [Player#close_inventories]
function Inventories:OneSecond()
  local stale = {}

  for id, inventory in pairs(Inventories.all()) do
    local receivers = inventory.receivers

    for i = 1, #receivers do
      local receiver = receivers[i]

      if IsValid(receiver) and !inventory:can_be_viewed_by(receiver) then
        local holder = inventory.owner or inventory
        local holders = stale[receiver] or {}
        local inventories = holders[holder] or {}

        stale[receiver] = holders
        holders[holder] = inventories
        inventories[#inventories + 1] = inventory
      end
    end
  end

  for receiver, holders in pairs(stale) do
    for holder, inventories in pairs(holders) do
      receiver:close_inventories(inventories)
    end
  end
end

--- Checks whether the item can be moved inside of the inventory: asks the can_move callback
-- of the item and prevents moving items in disabled inventories.
-- @param item_obj [Item]
-- @param inventory [Inventory]
-- @param x [Number target slot]
-- @param y [Number target slot]
-- @return [Boolean false to prevent the move, String text of the error; nothing to allow it]
function Inventories:CanItemMove(item_obj, inventory, x, y)
  if item_obj.can_move then
    local success, error_text = item_obj:can_move(inventory, x, y)

    if success == false then
      return false, error_text
    end
  end

  if inventory:is_disabled() then
    return false, 'error.inventory.disabled'
  end
end

--- Checks whether the item can be transferred to the inventory: equipment and pockets
-- restrictions, the can_transfer callback of the item, the can_contain callback
-- of the container the inventory belongs to, and whether the inventory is disabled.
-- @param item_obj [Item]
-- @param inventory [Inventory the inventory the item is being transferred to]
-- @param x [Number target slot, or nil if the position is yet to be found]
-- @param y [Number target slot, or nil if the position is yet to be found]
-- @return [Boolean false to prevent the transfer, String text of the error; nothing to allow it]
function Inventories:CanItemTransfer(item_obj, inventory, x, y)
  local inv_type = inventory.type

  if inv_type:start_with('equipment') and (!item_obj.equip_slot or item_obj.equip_inv != inv_type) then
    return false, 'error.inventory.cant_equip'
  end

  if inv_type == 'pockets' and !item_obj.pocket_size then
    return false, 'error.inventory.too_big'
  end

  if item_obj.can_transfer then
    local success, error_text = item_obj:can_transfer(inventory, x, y)

    if success == false then
      return false, error_text
    end
  end

  if inventory.instance_id then
    local item_container = Item.find_instance_by_id(inventory.instance_id)
    local success, error_text = item_container:can_contain(item_obj)

    if success == false then
      return false, error_text
    end
  end

  if inventory:is_disabled() then
    return false, 'error.inventory.disabled'
  end
end

--- Takes the equipped throwable items away from the player who has thrown a grenade.
-- @param actor [Player]
-- @param entity [Entity the grenade]
function Inventories:PlayerThrewGrenade(actor, entity)
  if !IsValid(actor) or !actor:IsPlayer() then return end

  local items = actor:get_items()

  for i = 1, #items do
    local item_obj = items[i]

    if item_obj:is('throwable') and item_obj:is_equipped() then
      actor:take_item_by_id(item_obj.instance_id)
    end
  end
end

--- Calls the on_use callback of the item, then takes the item out of its inventory (or removes
-- its entity) unless the callback returned true to keep it or false to cancel the use.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param ... [Vararg extra arguments of the action]
-- @return [Boolean false if the use was canceled, nil otherwise]
function Inventories:PlayerUseItem(actor, item_obj, ...)
  if item_obj.on_use then
    local result = item_obj:on_use(actor)

    if result == true then
      return
    elseif result == false then
      return false
    end
  end

  if IsValid(item_obj.entity) then
    item_obj.entity:Remove()
  else
    local inventory = Inventories.find(item_obj.inventory_id)

    hook.Run('PreItemTransfer', item_obj, nil, inventory)

    inventory:take_item_by_id(item_obj.instance_id)
    inventory:sync()

    hook.Run('ItemTransferred', item_obj, nil, inventory)
  end
end

--- Tells the client to rebuild the player model preview when a wearable item is equipped.
-- @param owner [Player]
-- @param item_obj [Item]
function Inventories:OnItemEquipped(owner, item_obj)
  if item_obj:is('wearable') then
    Cable.send(owner, 'fl_rebuild_player_panel')
  end
end

--- Tells the client to rebuild the player model preview when a wearable item is unequipped.
-- @param owner [Player]
-- @param item_obj [Item]
function Inventories:OnItemUnequipped(owner, item_obj)
  if item_obj:is('wearable') then
    Cable.send(owner, 'fl_rebuild_player_panel')
  end
end

--- Marks the item instance that has just been created as not rotated.
-- @param item_obj [Item]
function Inventories:OnItemCreated(item_obj)
  item_obj.rotated = false
end

Cable.receive('fl_item_move', function(actor, instance_ids, inventory_id, x, y, was_rotated)
  local old_inventory, stack = find_requested_stack(actor, instance_ids)
  local inventory = Inventories.find(inventory_id)

  if !old_inventory or !inventory or !inventory:has_receiver(actor) then return end
  if !isnumber(x) or !isnumber(y) or x != x or y != y then return end

  instance_ids = stack
  x, y = math.floor(x), math.floor(y)

  local instance_id = instance_ids[1]
  local item_obj = Item.find_instance_by_id(instance_id)

  --- Called on the server when a player asks to move items to an inventory slot by
  -- dragging them, before anything is moved. The target can be the inventory the items
  -- are in or another one. Requests that name items or inventories that do not exist,
  -- the same item twice, items from more than one inventory, an inventory that is not
  -- open for the player or a slot that is not a number are dropped before the hook is run.
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

  --- Called on the server when a player drops items by dragging them out of an
  -- inventory panel. The hook is what performs the drop: the Inventory plugin handles it
  -- by taking the items out of their inventory and spawning them in front of the player.
  -- Requests that name items that do not exist, the same item twice, items from more
  -- than one inventory, or an inventory that is not open for the player are dropped
  -- before the hook is run. The Items plugin runs the same hook with a single instance id
  -- instead of a list when a player uses the drop option of an item's menu, so a handler
  -- has to accept both.
  -- @param actor [Player The player dropping the items]
  -- @param instance_ids [List<Number> Instance ids of the items, all from one inventory]
  hook.Run('PlayerDropItem', actor, stack)
end)

Cable.receive('fl_inventory_close', function(actor, inventory_ids)
  if !istable(inventory_ids) then return end

  local closed_inventory

  for k, v in pairs(inventory_ids) do
    local inventory = Inventories.find(v)

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

Cable.receive('fl_character_desc_change', function(actor, text)
  if text:len() >= Config.get('character_min_desc_len') and text:len() <= Config.get('character_max_desc_len') then
    Characters.set_desc(actor, text)
    actor:notify('notification.char_desc_changed')
  end
end)
