--- Server side of the Containers plugin: opens a container when a player within reach asks
-- for it, plays its sounds, makes container props persistent, keeps the IDs of their items
-- on the props when persistent entities are saved, networks the names of the loaded
-- containers and deals with the inventory and the items of a container that is removed.

local detached_inventories = {}
local request_delay = 0.5

--- Closes the inventory of a removed entity for everyone who views it and deletes the
-- inventory from the server cache. If the entity is a container, its items are destroyed
-- or dropped on the ground as well, unless the map is unloading.
-- @param entity [Entity]
-- @see [Container#handle_removal]
function Container:EntityRemoved(entity)
  local inventory = entity.inventory

  if inventory then
    for k, v in ipairs(inventory.receivers) do
      if IsValid(v) then
        Cable.send(v, 'fl_inventory_close')
      end
    end

    Inventories.stored[inventory.id] = nil
  end

  if self:is_container(entity) then
    local item_ids = inventory and inventory:get_items_ids() or entity.items

    self:handle_removal(entity, inventory, istable(item_ids) and item_ids or {})
  end
end

--- Networks the custom names and the password marks of the containers that have been
-- loaded with the persistent entities. This is done on the next tick, once every handler
-- of the hook has spawned its entities and given them their saved fields back.
function Container:PersistenceLoad()
  timer.Simple(0, function()
    for k, v in ents.Iterator() do
      if (v.container_name or v.container_password) and self:is_container(v) then
        self:update_netvars(v)
      end
    end
  end)
end

--- Makes the spawned prop persistent if its model is a container.
-- @param actor [Player]
-- @param model [String]
-- @param entity [Entity]
function Container:PlayerSpawnedProp(actor, model, entity)
  if self:find(model) then
    entity:SetPersistent(true)
  end
end

--- Plays the closing sound of the container when its inventory gets closed.
-- @param actor [Player]
-- @param inventory [Inventory]
function Container:OnInventoryClosed(actor, inventory)
  local entity = inventory.owner

  if IsValid(entity) then
    local container_data = self:find(entity:GetModel())

    if container_data and container_data.close_sound then
      entity:EmitSound(container_data.close_sound, 55)
    end
  end
end

--- Stores the instance ids of the items of every container on its entity and takes the
-- inventory off the entity, so that it is not saved with it, before the persistent
-- entities are saved. The inventories are put back by the 'PostPersistenceSave' hook.
function Container:PrePersistenceSave()
  for k, v in ents.Iterator() do
    if v.inventory and self:find(v:GetModel()) then
      detached_inventories[v] = v.inventory

      v.items = v.inventory:get_items_ids()
      v.inventory = nil
    end
  end
end

--- Gives the containers their inventories back once the persistent entities have been
-- saved, so that the containers that are open at that moment keep working.
function Container:PostPersistenceSave()
  for entity, inventory in pairs(detached_inventories) do
    if IsValid(entity) then
      entity.inventory = inventory
      entity.items = nil
    end
  end

  detached_inventories = {}
end

--- Allows the container props to contain money.
-- @param object [Entity]
-- @return [Boolean true if the entity is a container, nil otherwise]
function Container:CanContainMoney(object)
  if IsValid(object) and isentity(object) and self:find(object:GetModel()) then
    return true
  end
end

Cable.receive('fl_container_open', function(actor, entity)
  local cur_time = CurTime()

  if actor.next_container_request and actor.next_container_request > cur_time then return end

  actor.next_container_request = cur_time + request_delay

  Container:request_open(actor, entity)
end)
