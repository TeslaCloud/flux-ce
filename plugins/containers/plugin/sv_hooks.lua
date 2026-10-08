--- Server side of the Containers plugin: creates the inventory of a container when a player
-- within reach opens it, plays its sounds, makes container props persistent and keeps the
-- IDs of their items on the props when persistent entities are saved.

local detached_inventories = {}

--- Closes the inventory of a removed entity for everyone who views it
-- and deletes the inventory from the server cache.
-- @param entity [Entity]
function Container:EntityRemoved(entity)
  if entity.inventory then
    local inventory = entity.inventory

    for k, v in ipairs(inventory.receivers) do
      if IsValid(v) then
        Cable.send(v, 'fl_inventory_close')
      end
    end

    Inventories.stored[inventory.id] = nil
  end
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
  if !IsValid(entity) or entity:GetClass() != 'prop_physics' then return end
  if !Inventories.is_in_reach(actor, entity) then return end

  local container_data = Container:find(entity:GetModel())

  if container_data then
    if !entity.inventory then
      local inventory = Inventory.new()
      inventory:set_size(container_data.w, container_data.h)
      inventory.title = container_data.name
      inventory.type = 'container'
      inventory.multislot = (container_data != nil) and true or false
      inventory.owner = entity

      if entity.items then
        inventory:load_items(entity.items)

        entity.items = nil
      end

      entity.inventory = inventory
    end

    if container_data.open_sound then
      entity:EmitSound(container_data.open_sound, 55)
    end

    --- Called on the server when a player opens a container, after its inventory has been
    -- created or found and its opening sound played, right before the inventory is shown to
    -- the player. The player is not passed to the hook.
    -- @param entity [Entity the container prop; its inventory is entity.inventory]
    hook.Run('PreContainerOpen', entity)

    actor:open_inventory(entity.inventory, entity)
  end
end)
