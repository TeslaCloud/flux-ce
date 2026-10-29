--- Server side of the Items plugin: loads the items of the map, has the changes of the items
-- written to the database, checks whether a player may perform a menu action on an item,
-- and calls the `on_drop`, `on_destroy`, `on_loadout`, `on_save` and `on_created` callbacks
-- of items. It also destroys items on request of their owners, keeps players away from the
-- items that another of their characters has dropped, and drops the weapons of players
-- who die, each of which a config key turns on.

local pairs = pairs
local IsValid = IsValid

local use_distance_sqr = 100 * 100
local min_aim_dot = math.pi * 0.125

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
        -- Inventory plugin uses it to take the equipped throwable item away from the
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
-- With the 'item_drop_ownership' config on, it also keeps players away from the items in
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

    local player_pos = actor:EyePos()
    local entity_pos = item_entity:GetPos()

    if player_pos:DistToSqr(entity_pos) > use_distance_sqr then
      return false
    end

    if util.vector_obstructed(player_pos, entity_pos, { item_entity, actor }) then
      return false
    end

    local entity_vector = entity_pos - actor:GetShootPos()

    if (actor:GetAimVector():Dot(entity_vector) / entity_vector:Length()) < min_aim_dot then
      return false
    end

    if Config.get('item_drop_ownership') and item_entity:is_dropped_by_other_character(actor) then
      actor:notify('error.item.other_character')

      return false
    end
  else
    if !actor:has_item_by_id(item_obj.instance_id) then
      return false
    end
  end
end

--- Sends an item that is lying in the world again to the clients that know it, after a
-- menu action has been performed on it.
-- @param _actor [Player]
-- @param item_obj [Item]
-- @param _act [String name of the menu action]
-- @param ... [Vararg extra arguments of the action]
function Items:PlayerUsedItem(_actor, item_obj, _act, ...)
  if IsValid(item_obj.entity) then
    Item.network_item(nil, item_obj.instance_id)
    Item.network_entity_data(nil, item_obj.entity)
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
  if !Inventories or IsValid(item_obj.entity) or !item_obj:is_destroyable() then
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

  --- Called on the server right before an item leaves its inventory for good: here when
  -- a player destroys it, and also when a dying player drops their equipped weapon
  -- items. The Inventory plugin runs the same hook for every other transfer and handles
  -- it by calling the `on_transfer` callback of the item, which is how an equipped item
  -- gets unequipped. A handler may take the item out of the inventory by itself.
  -- @param item_obj [Item The item that is about to leave]
  -- @param new_inventory [Inventory Always nil here: the item does not go to another
  --   inventory]
  -- @param old_inventory [Inventory The inventory the item is in]
  hook.Run('PreItemTransfer', item_obj, nil, inventory)

  if item_obj.inventory_id == inventory.id then
    inventory:take_item_by_id(item_obj.instance_id)
  end

  inventory:sync()

  --- Called on the server right after an item has left its inventory for good: here when
  -- a player has destroyed it, in which case the instance is removed right afterward, and
  -- also when a dying player has dropped an equipped weapon item, before its entity is
  -- spawned. The Inventory plugin runs the same hook for every other transfer.
  -- @param item_obj [Item The item that has left]
  -- @param new_inventory [Inventory Always nil here]
  -- @param old_inventory [Inventory The inventory the item was in]
  hook.Run('ItemTransferred', item_obj, nil, inventory)

  Item.remove(item_obj)

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

  if !Inventories then
    return dropped
  end

  local position = victim:GetPos()
  local changed = {}

  for _, entry in pairs(victim:get_items()) do
    local inventory = Inventories.find(entry.inventory_id)

    if entry.weapon_class and entry.is_equipped and entry:is_equipped() and inventory and inventory.owner == victim then
      --- Called on the server before an equipped weapon item of a dying player is dropped
      -- into the world, which happens when the `drop_weapons_on_death` config is on. The
      -- `PlayerCanDropItem` hook, and with it the `on_drop` callback of the item, is asked
      -- afterward.
      -- @param victim [Player The player who is dying]
      -- @param item_obj [Item The equipped weapon item]
      -- @return [Boolean Return false to leave the item in the inventory of the player]
      local can_drop = hook.Run('PlayerCanDropWeaponOnDeath', victim, entry) != false

      --- Called on the server before an item is dropped from an inventory into the world.
      -- The Items plugin runs it here for every equipped weapon item of a dying player
      -- that `PlayerCanDropWeaponOnDeath` has let go of; the Inventory plugin runs it when
      -- a player drops items. The Items plugin handles it by asking the `on_drop` callback
      -- of the item and by naming the player as the dropper of the item.
      -- @param actor [Player The player dropping the item]
      -- @param item_obj [Item The item that is about to be dropped]
      -- @return [Boolean Return false to prevent the drop]
      if can_drop and hook.Run('PlayerCanDropItem', victim, entry) != false then
        hook.Run('PreItemTransfer', entry, nil, inventory)

        if entry.inventory_id == inventory.id then
          inventory:take_item_by_id(entry.instance_id)

          hook.Run('ItemTransferred', entry, nil, inventory)

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
-- 'drop_weapons_on_death' config is on. It is done here rather than in PlayerDeath so that
-- the weapons are still there for the items to store their clips, and so that the items
-- are gone from the inventory before the character is saved.
-- @param victim [Player]
-- @param _attacker [Entity]
-- @param _damage_info [CTakeDamageInfo]
function Items:DoPlayerDeath(victim, _attacker, _damage_info)
  if Config.get('drop_weapons_on_death') then
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
function Items:OnCharacterItemsLoaded(owner, _character, _items)
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

--- Calls the on_created callback of an item instance that has just been created.
-- @param item_obj [Item]
function Items:OnItemCreated(item_obj)
  if item_obj.on_created then
    item_obj:on_created()
  end
end

Cable.receive('fl_items_abort_hold_start', function(actor)
  local ent = actor:get_nv('hold_entity')

  if IsValid(ent) then
    ent:set_nv('last_activator', false)
  end

  actor:set_nv('hold_start', false)
  actor:set_nv('hold_entity', false)
end)
