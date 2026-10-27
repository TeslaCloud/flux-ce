--- Server side of the Containers plugin: opens a container when a player within reach asks
-- for it, plays its sounds, makes container props persistent, gives the containers the
-- items that are loaded for them, keeps their inventories out of the saved persistent
-- entities, networks the names of the loaded containers, deals with the inventory and the
-- items of a container that is removed and keeps the items of the containers through a map
-- cleanup.

local detached_inventories = {}
local request_delay = 0.5

--- Closes the inventory of a removed entity for everyone who views it and deletes the
-- inventory from the server cache. If the entity is a container, its items are destroyed
-- or dropped on the ground as well, unless the map is unloading or being cleaned up; in
-- that case they wait for the container to come back.
-- @param entity [Entity]
-- @see [Container#handle_removal]
function Container:EntityRemoved(entity)
  local inventory = entity.inventory

  if inventory then
    for _, receiver in ipairs(inventory.receivers) do
      if IsValid(receiver) then
        Cable.send(receiver, 'fl_inventory_close')
      end
    end

    Inventories.stored[inventory.id] = nil
  end

  if !self:is_container(entity) then return end

  local item_ids = inventory and inventory:get_items_ids() or {}

  for _, item_obj in ipairs(self:get_pending_items(entity)) do
    item_ids[#item_ids + 1] = item_obj.instance_id
  end

  if (Flux.shutting_down or self.cleaning_up) and entity.container_id then
    local kept = {}

    for _, instance_id in ipairs(item_ids) do
      local item_obj = Item.find_instance_by_id(instance_id)

      if item_obj and item_obj.container_id == entity.container_id then
        item_obj.inventory_id = nil
        kept[#kept + 1] = item_obj
      end
    end

    self.pending[entity.container_id] = kept
  end

  self:handle_removal(entity, inventory, item_ids)
end

--- Gives the containers of the map the items that have been loaded for them. Containers
-- that are not there yet get them once they are.
-- @param items [List<Item>]
function Container:OnMapItemsLoaded(items)
  local by_container = {}

  for _, item_obj in ipairs(items) do
    local container_id = item_obj.container_id

    if container_id and !item_obj.inventory_id then
      local list = by_container[container_id] or {}

      list[#list + 1] = item_obj
      by_container[container_id] = list
    end
  end

  for container_id, list in pairs(by_container) do
    self:add_pending_items(container_id, list)
  end

  self:claim_pending_items()
  self:release_unclaimed_items_later()
end

--- Creates the inventory of every container that has loaded items waiting for it, which
-- puts the items into it.
function Container:claim_pending_items()
  if table.IsEmpty(self.pending) then return end

  for _, entity in ents.Iterator() do
    if entity.container_id and self.pending[entity.container_id] and self:is_container(entity) then
      self:get_inventory(entity)
    end
  end
end

--- Marks that the map is being cleaned up, so that the items of the containers that the
-- cleanup removes are left alone: the persistent props are saved right before the cleanup
-- and spawned again right after it, and their items, which stay saved as being in them,
-- come back with them.
function Container:PreCleanupMap()
  self.cleaning_up = true
end

--- Ends the map cleanup, after which removed containers lose their items again.
function Container:PostCleanupMap()
  self.cleaning_up = nil

  self:release_unclaimed_items_later()
end

--- Networks the custom names, the password marks and the money of the containers that
-- have been loaded with the persistent entities, and gives the containers the items that
-- have been loaded for them. This is done on the next tick, once every handler of the hook
-- has spawned its entities and given them their saved fields back.
function Container:PersistenceLoad()
  timer.Simple(0, function()
    for _, entity in ents.Iterator() do
      if (entity.container_name or entity.container_password) and self:is_container(entity) then
        self:update_netvars(entity)
      end

      if istable(entity.currencies) and self:is_container(entity) then
        entity:set_nv('fl_currencies', entity.currencies)
      end
    end

    self:claim_pending_items()
  end)
end

--- Makes the spawned prop persistent if its model is a container, and gives it the number
-- its items are saved under, which saves the persistent entities shortly afterward.
-- @param _actor [Player]
-- @param model [String]
-- @param entity [Entity]
function Container:PlayerSpawnedProp(_actor, model, entity)
  if self:find(model) then
    entity:SetPersistent(true)

    self:get_container_id(entity)
  end
end

--- Plays the closing sound of the container when its inventory gets closed.
-- @param _actor [Player]
-- @param inventory [Inventory]
function Container:OnInventoryClosed(_actor, inventory)
  local entity = inventory.owner

  if IsValid(entity) then
    local container_data = self:find(entity:GetModel())

    if container_data and container_data.close_sound then
      entity:EmitSound(container_data.close_sound, 55)
    end
  end
end

--- Takes the inventory off every container before the persistent entities are saved, so
-- that it is not saved with it. The inventories are put back by the 'PostPersistenceSave'
-- hook.
function Container:PrePersistenceSave()
  for _, entity in ents.Iterator() do
    if entity.inventory and self:find(entity:GetModel()) then
      detached_inventories[entity] = entity.inventory

      entity.inventory = nil
    end
  end
end

--- Gives the containers their inventories back once the persistent entities have been
-- saved, so that the containers that are open at that moment keep working.
function Container:PostPersistenceSave()
  for entity, inventory in pairs(detached_inventories) do
    if IsValid(entity) then
      entity.inventory = inventory
    end
  end

  detached_inventories = {}
end

--- Allows the containers, physics props with a container model, to contain money.
-- @param object [Entity]
-- @return [Boolean true if the entity is a container, nil otherwise]
function Container:CanContainMoney(object)
  if self:is_container(object) then
    return true
  end
end

Cable.receive('fl_container_open', function(actor, entity)
  local cur_time = CurTime()

  if actor.next_container_request and actor.next_container_request > cur_time then return end

  actor.next_container_request = cur_time + request_delay

  Container:request_open(actor, entity)
end)
