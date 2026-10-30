--- Server hooks of the Items plugin: loads the items of the map, has the changes of the
-- items written to the database, checks whether a player may perform a menu action on an
-- item, does what the take, use and drop actions of items are supposed to do, and calls the
-- `on_drop`, `on_destroy`, `on_loadout`, `on_save`, `on_created` and `on_transfer`
-- callbacks of items. It also creates the default inventories of players, loads and unloads
-- the items of characters, enforces the rules of moving items between inventories, closes
-- the inventories that players are no longer entitled to. Config keys turn on destroying
-- items on request of their owners, keeping players away from items another of their
-- characters has dropped, and dropping the weapons of players who die.

local pairs = pairs
local IsValid = IsValid

local drop_near_distance_sqr = 80 * 80
local min_aim_dot = math.pi * 0.125

Cable.check_networked_string('fl_inventories_clear')

local function has_contents(item_obj)
  return item_obj.inventory != nil and !item_obj.inventory:is_empty()
end

--- Loads the items of the current map once both the map entities and the database are
-- there, which can happen in either order.
function Items:load_map_items()
  if self.map_items_loaded or !self.entities_ready or !Item.is_storage_ready() then return end

  self.map_items_loaded = true

  Item.load_map()
end

--- Reserves the first block of item instance ids and loads the items of the map, if the
-- map entities are there already.
function Items:ActiveRecordReady()
  Item.reserve_ids()

  self:load_map_items()
end

--- Loads the items of the map once the map entities have been created, if the database is
-- ready already.
function Items:InitPostEntity()
  self.entities_ready = true

  self:load_map_items()
end

--- Runs the 'PlayerThrewGrenade' hook on the next tick after a frag grenade is created.
-- @param entity [Entity]
function Items:OnEntityCreated(entity)
  if IsValid(entity) and entity:GetClass() == 'npc_grenade_frag' then
    timer.Simple(0, function()
      if IsValid(entity) then
        local owner = entity:GetOwner()

        --- Called on the server when a frag grenade has been thrown.
        -- It runs on the next tick after an `npc_grenade_frag` entity is created. The
        -- Items plugin uses it to take the equipped throwable item away from the
        -- thrower.
        -- @param owner [Entity The owner of the grenade, normally the player who threw it;
        --   it is not checked for validity and is not necessarily a player]
        -- @param entity [Entity The grenade]
        hook.Run('PlayerThrewGrenade', owner, entity)
      end
    end)
  end
end

--- Marks the items lying in the world that have moved, so that they are written with the
-- next save.
function Items:SaveData()
  Item.mark_world_dirty()
end

--- Writes the changes of the items to the database once everything else has been saved.
-- While the server shuts down or changes the map, it waits until the database has run
-- the queries, and reports the items that could not be written.
function Items:PostSaveData()
  if !Flux.shutting_down then
    Item.save()

    return
  end

  local failures = Item.save(nil, true)

  if #failures > 0 then
    local ids = {}

    for index, item_obj in ipairs(failures) do
      ids[index] = item_obj.instance_id
    end

    ErrorNoHalt('These items could not be saved before the shutdown: '..table.concat(ids, ', ')..'\n')
  end
end

--- Sends the item entity the player has used to them, along with its item, and tells their
-- client to open the menu of the item.
-- @param activator [Player]
-- @param entity [Entity the fl_item entity]
-- @param _item_obj [Item]
function Items:PlayerUseItemEntity(activator, entity, _item_obj)
  Item.send_entity(activator, entity)

  Cable.send(activator, 'fl_player_use_item_entity', entity)
end

--- Prevents menu actions of players who are dead or lie on the ground as a ragdoll, on
-- items that the player does not have, and on items in the world that are too far away from
-- the player, obstructed, not being looked at or already on their way out of the world.
-- With the 'items_drop_ownership' config on, it also keeps players away from the items in
-- the world that another of their own characters has dropped.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param _action [String name of the menu action]
-- @param ... [Vararg extra arguments of the action]
-- @return [Boolean false to prevent the action, nil otherwise]
function Items:PlayerCanUseItem(actor, item_obj, _action, ...)
  if !actor:Alive() or (isfunction(actor.is_ragdolled) and actor:is_ragdolled()) then
    return false
  end

  local item_entity = item_obj.entity

  if IsValid(item_entity) then
    if item_entity:IsMarkedForDeletion() then
      return false
    end

    if !actor:is_in_reach(item_entity, 100) then
      return false
    end

    local player_pos = actor:EyePos()
    local entity_pos = item_entity:GetPos()

    if util.vector_obstructed(player_pos, entity_pos, { item_entity, actor }) then
      return false
    end

    local entity_vector = entity_pos - actor:GetShootPos()

    if (actor:GetAimVector():Dot(entity_vector) / entity_vector:Length()) < min_aim_dot then
      return false
    end

    if Config.get('items_drop_ownership') and item_entity:is_dropped_by_other_character(actor) then
      actor:notify('error.item.other_character')

      return false
    end
  else
    if !actor:has_item_by_id(item_obj.instance_id) then
      return false
    end
  end
end

--- Sends an item that is lying in the world again to the clients that know it, or
-- synchronizes the inventory of an item that is in one, after a menu action has been
-- performed on it.
-- @param _actor [Player]
-- @param item_obj [Item]
-- @param _act [String name of the menu action]
-- @param ... [Vararg extra arguments of the action]
function Items:PlayerUsedItem(_actor, item_obj, _act, ...)
  if IsValid(item_obj.entity) then
    Item.network_item(nil, item_obj.instance_id)
    Item.network_entity_data(nil, item_obj.entity)
  end

  local inventory = item_obj.inventory_id and Inventories.find(item_obj.inventory_id)

  if inventory then
    inventory:sync()
  end
end

--- Lets the on_drop callback of the item decide whether the player is able to drop it.
-- @param actor [Player]
-- @param item_obj [Item]
-- @return [Boolean false to prevent the drop, nil otherwise]
function Items:PlayerCanDropItem(actor, item_obj)
  if !istable(item_obj) then return end

  if item_obj.on_drop and item_obj:on_drop(actor) == false then
    return false
  end
end

--- Destroys an item that is in an inventory on request of the player: asks the
-- 'PlayerCanDestroyItem' hook and the on_destroy callback of the item, takes the item
-- out of its inventory, removes the instance and runs the 'PlayerDestroyedItem' hook.
-- @param actor [Player]
-- @param item_obj [Item]
-- @return [Boolean false if the item has not been destroyed, nil otherwise]
function Items:PlayerDestroyItem(actor, item_obj)
  if IsValid(item_obj.entity) or !item_obj:is_destroyable() then
    return false
  end

  local inventory = Inventories.find(item_obj.inventory_id)

  if !inventory then
    return false
  end

  if inventory:is_disabled() then
    actor:notify('error.inventory.disabled')

    return false
  end

  --- Called on the server before a player destroys an item from an inventory through
  -- the menu of the item. The Items plugin uses it to refuse equipped items that their
  -- `can_unequip` callback does not let go of, and container items that are not empty.
  -- The `on_destroy` callback of the item is asked afterward, if no handler has refused.
  -- @param actor [Player The player destroying the item]
  -- @param item_obj [Item The item that is about to be destroyed]
  -- @return [Boolean Return false to prevent the destruction, String Error phrase to
  --   notify the player with]
  local can_destroy, error_text = hook.Run('PlayerCanDestroyItem', actor, item_obj)

  if can_destroy != false and item_obj.on_destroy then
    can_destroy, error_text = item_obj:on_destroy(actor)
  end

  if can_destroy == false then
    if isstring(error_text) then
      actor:notify(error_text)
    end

    return false
  end

  if !inventory:destroy_item(item_obj) then
    return false
  end

  --- Called on the server after a player has destroyed an item through its menu. The
  -- item has been taken out of its inventory and its instance has been removed by now,
  -- so `item_obj` is only good for looking at what the item was.
  -- @param actor [Player The player who destroyed the item]
  -- @param item_obj [Item The destroyed item]
  hook.Run('PlayerDestroyedItem', actor, item_obj)
end

--- Keeps players from destroying equipped items that cannot be unequipped, and container
-- items that still have something inside.
-- @param actor [Player]
-- @param item_obj [Item]
-- @return [Boolean false to prevent the destruction, String error phrase; nothing to allow it]
function Items:PlayerCanDestroyItem(actor, item_obj)
  if item_obj.is_equipped and item_obj:is_equipped() and item_obj.can_unequip
  and item_obj:can_unequip(actor) == false then
    return false
  end

  if has_contents(item_obj) then
    return false, 'error.item.destroy_not_empty'
  end
end

--- Keeps container items that still have something inside from being damaged while they
-- lie in the world, so that their contents are not lost along with them.
-- @param _entity [Entity the fl_item entity]
-- @param item_obj [Item]
-- @param _damage_info [CTakeDamageInfo]
-- @return [Boolean false to ignore the damage, nil otherwise]
function Items:CanItemEntityTakeDamage(_entity, item_obj, _damage_info)
  if has_contents(item_obj) then
    return false
  end
end

--- Drops the equipped weapon items of a player into the world at the position of the
-- player. Each item goes through the 'PlayerCanDropWeaponOnDeath' and 'PlayerCanDropItem'
-- hooks first; the 'PlayerDroppedWeaponOnDeath' hook is run for every item that drops.
-- @param victim [Player]
-- @return [List<Entity> the item entities that have been spawned]
function Items:drop_weapons(victim)
  local dropped = {}
  local position = victim:GetPos()
  local changed = {}

  for _, entry in pairs(victim:get_items()) do
    local inventory = Inventories.find(entry.inventory_id)

    if entry.weapon_class and entry.is_equipped and entry:is_equipped() and inventory and inventory.owner == victim then
      --- Called on the server before an equipped weapon item of a dying player is dropped
      -- into the world, which happens when the `items_drop_weapons_on_death` config is on. The
      -- `PlayerCanDropItem` hook, and with it the `on_drop` callback of the item, is asked
      -- afterward.
      -- @param victim [Player The player who is dying]
      -- @param item_obj [Item The equipped weapon item]
      -- @return [Boolean Return false to leave the item in the inventory of the player]
      local can_drop = hook.Run('PlayerCanDropWeaponOnDeath', victim, entry) != false

      --- Called on the server before an item is dropped from an inventory into the world.
      -- The Items plugin runs it here for every equipped weapon item of a dying player
      -- that `PlayerCanDropWeaponOnDeath` has let go of, and when a player drops items from
      -- an inventory. The Items plugin handles it by asking the `on_drop` callback
      -- of the item and by naming the player as the dropper of the item.
      -- @param actor [Player The player dropping the item]
      -- @param item_obj [Item The item that is about to be dropped]
      -- @return [Boolean Return false to prevent the drop]
      if can_drop and hook.Run('PlayerCanDropItem', victim, entry) != false then
        if inventory:release_item(entry) then
          local offset = Vector(0, 0, 16 + #dropped * 8)
          local entity = Item.spawn(position + offset, Angle(0, math.random(0, 359), 0), entry, victim)

          dropped[#dropped + 1] = entity

          --- Called on the server after an equipped weapon item of a dying player has
          -- been taken out of their inventory and dropped into the world.
          -- @param victim [Player The player who is dying]
          -- @param item_obj [Item The weapon item]
          -- @param entity [Entity The `fl_item` entity the item lies in the world as]
          hook.Run('PlayerDroppedWeaponOnDeath', victim, entry, entity)
        end

        changed[inventory] = true
      end
    end
  end

  for inventory in pairs(changed) do
    inventory:sync()
  end

  return dropped
end

--- Drops the equipped weapon items of a player who is dying, if the
-- 'items_drop_weapons_on_death' config is on. It is done here rather than in PlayerDeath so that
-- the weapons are still there for the items to store their clips, and so that the items
-- are gone from the inventory before the character is saved.
-- @param victim [Player]
-- @param _attacker [Entity]
-- @param _damage_info [CTakeDamageInfo]
function Items:DoPlayerDeath(victim, _attacker, _damage_info)
  if Config.get('items_drop_weapons_on_death') then
    self:drop_weapons(victim)
  end
end

local function give_loadout(actor)
  for _, item_obj in pairs(actor:get_items()) do
    if item_obj.on_loadout then
      item_obj:on_loadout(actor)
    end
  end
end

--- Calls the on_loadout callback of every item that the player has, once per spawn: on
-- the next tick after they spawn with their character loaded, or once the items of the
-- character have been loaded if that takes longer.
-- @param actor [Player]
function Items:PostPlayerSpawn(actor)
  if !actor:is_character_loaded() then return end

  actor.loadout_pending = true

  timer.Simple(0, function()
    if IsValid(actor) and actor.loadout_pending and !actor.loading_items then
      actor.loadout_pending = nil

      give_loadout(actor)
    end
  end)
end

--- Calls the on_loadout callback of the items of a character that have just been loaded,
-- if the player has spawned and has not had them yet.
-- @param owner [Player]
-- @param _character [Character]
-- @param _items [List<Item>]
function Items:CharacterItemsLoaded(owner, _character, _items)
  if owner.loadout_pending and owner:Alive() then
    owner.loadout_pending = nil

    give_loadout(owner)
  end
end

--- Calls the on_save callback of every item that the player has before their character is
-- saved, and writes the changes of the items along with the character.
-- @param owner [Player]
-- @param _index [Character the character that is being saved]
function Items:PreSaveCharacter(owner, _index)
  local items = owner:get_items()

  for _, item_obj in ipairs(items) do
    if item_obj.on_save then
      item_obj:on_save(owner)
    end

    Item.mark_dirty(item_obj)
  end

  Item.save(items, Flux.shutting_down == true)
end

--- Calls the on_created callback of an item instance that has just been created, then
-- marks the instance as not rotated.
-- @param item_obj [Item]
function Items:ItemCreated(item_obj)
  if item_obj.on_created then
    item_obj:on_created()
  end

  item_obj.rotated = false
end

--- Marks a character that has just been created as one that still has to get its
-- starting items, which happens the first time it is loaded.
-- @param _owner [Player]
-- @param char [Character]
-- @param _char_data [Map data the character was created from]
function Items:PostCreateCharacter(_owner, char, _char_data)
  Characters.set_custom_data(char, 'default_items_pending', true)
end

--- Unloads the items of the disconnected player's character and deletes their inventories
-- from the server cache. The items are unloaded on the next tick, once the character has
-- been saved.
-- @param actor [Player]
function Items:PlayerDisconnected(actor)
  actor:unload_items(true)
  actor:delete_inventories()
end

--- Unloads the items of the player's previous character, if they had one, and recreates
-- their inventories for the new character, which loads its items.
-- @param owner [Player]
-- @param _character [Character]
function Items:ActiveCharacterSet(owner, _character)
  owner:unload_items()
  owner:delete_inventories()
  owner:create_inventories()
end

--- Unloads the items of the character that the player drops, takes its inventories away
-- from the player, leaving them without inventories as they were before they loaded a
-- character, and tells their client to forget its copies of them.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function Items:ActiveCharacterCleared(owner, _character)
  owner:unload_items()
  owner:delete_inventories()
  owner.inventories = nil
  owner.default_inventory = nil

  if !owner:IsBot() then
    Cable.send(owner, 'fl_inventories_clear')
  end
end

--- Creates the default set of the player's inventories:
-- main inventory, hotbar, pockets and the equipment slots.
-- @param _owner [Player]
-- @param inventories [Map table to put the new inventories into, keyed by inventory type]
function Items:AdjustPlayerInventories(_owner, inventories)
  local main_inventory = Inventory.new()
    main_inventory.title = 'ui.inventory.main_inventory'
    main_inventory:set_size(Config.get('items_inventory_width'), Config.get('items_inventory_height'))
    main_inventory.type = 'main_inventory'
    main_inventory.default = true
  inventories[main_inventory.type] = main_inventory

  local hotbar = Inventory.new()
    hotbar.title = 'ui.inventory.hotbar'
    hotbar:set_size(Config.get('items_hotbar_width'), Config.get('items_hotbar_height'))
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
    pockets:set_size(1, Config.get('items_pockets_height'))
    pockets.type = 'pockets'
    pockets.infinite_width = true
    pockets.multislot = false
  inventories[pockets.type] = pockets
end

--- Deletes the items of a character that is about to be deleted.
-- @param _actor [Player]
-- @param id [Number ID of the character]
-- @param _character [Character]
function Items:PreDeleteCharacter(_actor, id, _character)
  Item.delete_character_items(id)
end

--- Puts the contents of the container items of the map into the inventories of their
-- container items once the items of the map have been loaded. Contents that do not fit
-- are unloaded again.
-- @param items [List<Item>]
function Items:MapItemsLoaded(items)
  Item.unload(Inventories.place_items(items))
end

--- Adds the position of the item in its inventory and its rotation to what a client is sent
-- about the item.
-- @param item_obj [Item]
-- @param fields [Map fields of the item that are going to be sent]
function Items:PreItemNetwork(item_obj, fields)
  fields.x = item_obj.x
  fields.y = item_obj.y
  fields.inventory_type = item_obj.inventory_type
  fields.inventory_id = item_obj.inventory_id
  fields.rotated = item_obj.rotated
end

--- Puts an item lying in the world into one of the player's inventories
-- and removes its entity. Nothing happens if the player has no inventory of the requested
-- type; the player is notified if the 'CanItemTransfer' hook refuses the inventory or the
-- item does not fit.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param ... [Vararg optional hashes; an inv_type field in one of them sets the inventory type]
function Items:PlayerTakeItem(actor, item_obj, ...)
  local item_entity = item_obj.entity

  if IsValid(item_entity) and !item_entity:IsMarkedForDeletion() then
    local inv_type

    for _, argument in pairs({ ... }) do
      if istable(argument) then
        for key, value in pairs(argument) do
          if key == 'inv_type' then
            inv_type = value
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
      item_entity:Remove()

      hook.Run('ItemTransferred', item_obj, player_inventory)
    else
      actor:notify(error_text)
    end
  end
end

--- Takes the items out of their inventory and spawns them in front of the player. Does
-- nothing if the first item does not exist, is not in an inventory or its inventory is
-- disabled; stops at the first item that is not in that inventory. An item that a
-- 'PreItemTransfer' handler takes out of the inventory by itself is not spawned.
-- @param actor [Player]
-- @param instance_ids [Number/List<Number> instance id(s) of items from the same inventory]
function Items:PlayerDropItem(actor, instance_ids)
  if isnumber(instance_ids) then
    instance_ids = { instance_ids }
  end

  local trace = actor:GetEyeTraceNoCursor()
  local first_item = Item.find_instance_by_id(table.first(instance_ids))
  local inventory = first_item and Inventories.find(first_item.inventory_id)

  if !inventory or inventory:is_disabled() then return end

  local drop_near = trace.HitPos:DistToSqr(actor:GetPos()) < drop_near_distance_sqr

  for index, instance_id in ipairs(instance_ids) do
    local item_obj = Item.find_instance_by_id(instance_id)

    if !item_obj or item_obj.inventory_id != inventory.id then break end

    --- Called on the server before a player drops an item from an inventory into the
    -- world, once for every item of a dropped stack. The Items plugin uses it to ask the
    -- `on_drop` callback of the item.
    -- @param actor [Player The player dropping the item]
    -- @param item_obj [Item The item that is about to be dropped]
    -- @return [Boolean Return false to prevent the drop; the items of the stack that
    --   come after this one are not dropped either]
    if hook.Run('PlayerCanDropItem', actor, item_obj) == false then break end

    if !inventory:release_item(item_obj) then continue end

    if drop_near then
      Item.spawn(trace.HitPos + Vector(0, 0, 5) * index, Angle(0, 0, 0), item_obj, actor)
    else
      local ent = Item.spawn(actor:EyePos() + trace.Normal * 20 + VectorRand() * 5, Angle(0, 0, 0), item_obj, actor)
      local phys_obj = ent:GetPhysicsObject()

      if IsValid(phys_obj) then
        phys_obj:ApplyForceCenter(trace.Normal * 200)
      end
    end
  end

  inventory:sync()
end

--- Calls the on_transfer callback of the item before it changes its inventory.
-- @param item_obj [Item]
-- @param new_inventory [Inventory where the item goes, or nil if it is dropped or used up]
-- @param old_inventory [Inventory where the item was, or nil if it is picked up]
function Items:PreItemTransfer(item_obj, new_inventory, old_inventory)
  if item_obj.on_transfer then
    item_obj:on_transfer(new_inventory, old_inventory)
  end
end

--- Closes the inventory of a transferred container item
-- for the players who were viewing it and do not have the container anymore.
-- @param item_obj [Item]
-- @param _new_inventory [Inventory where the item went, or nil if it was dropped or used up]
-- @param _old_inventory [Inventory where the item was, or nil if it was picked up]
function Items:ItemTransferred(item_obj, _new_inventory, _old_inventory)
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
-- that the 'InventoryClosed' hook runs once when, for example, a player walks away from
-- another player whose inventories they were viewing.
-- @see [Inventory#can_be_viewed_by]
-- @see [Player#close_inventories]
function Items:OneSecond()
  local stale = {}

  for _id, inventory in pairs(Inventories.all()) do
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
    for _holder, inventories in pairs(holders) do
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
function Items:CanItemMove(item_obj, inventory, x, y)
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
function Items:CanItemTransfer(item_obj, inventory, x, y)
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

    if !item_container then
      return false, 'error.inventory.invalid_item'
    end

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
-- @param _entity [Entity the grenade]
function Items:PlayerThrewGrenade(actor, _entity)
  if !IsValid(actor) or !actor:IsPlayer() then return end

  local items = actor:get_items()

  for i = 1, #items do
    local item_obj = items[i]

    if item_obj:is('throwable') and item_obj:is_equipped() then
      actor:take_item_by_id(item_obj.instance_id)
    end
  end
end

--- Calls the on_use callback of the item, then takes the item out of its inventory and
-- removes it, along with its entity if it lies in the world, unless the callback returned
-- true to keep it or false to cancel the use. The callback cannot be undone, so an item
-- that a `PreItemTransfer` handler takes out of its inventory by itself is kept where the
-- handler has put it.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param ... [Vararg extra arguments of the action]
-- @return [Boolean false if the use was canceled, nil otherwise]
function Items:PlayerUseItem(actor, item_obj, ...)
  if item_obj.on_use then
    local result = item_obj:on_use(actor)

    if result == true then
      return
    elseif result == false then
      return false
    end
  end

  local inventory = !IsValid(item_obj.entity) and Inventories.find(item_obj.inventory_id)

  if inventory then
    inventory:destroy_item(item_obj)
  else
    Item.remove(item_obj)
  end
end

--- Tells the client to rebuild the player model preview when a wearable item is equipped.
-- @param owner [Player]
-- @param item_obj [Item]
function Items:ItemEquipped(owner, item_obj)
  if item_obj:is('wearable') then
    Cable.send(owner, 'fl_rebuild_player_panel')
  end
end

--- Tells the client to rebuild the player model preview when a wearable item is unequipped.
-- @param owner [Player]
-- @param item_obj [Item]
function Items:ItemUnequipped(owner, item_obj)
  if item_obj:is('wearable') then
    Cable.send(owner, 'fl_rebuild_player_panel')
  end
end
