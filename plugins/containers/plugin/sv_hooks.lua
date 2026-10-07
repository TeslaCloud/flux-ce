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

--- Stores the instance ids of the items of every container on its entity
-- and unsets the inventory, before the persistent entities are saved.
function Container:PrePersistenceSave()
  for k, v in ipairs(ents.GetAll()) do
    if v.inventory and self:find(v:GetModel()) then
      v.items = v.inventory:get_items_ids()
      v.inventory = nil
    end
  end
end

--- Allows the container props to contain money.
-- @param object [Entity]
-- @return [Boolean true if the entity is a container, nil otherwise]
function Container:CanContainMoney(object)
  if IsValid(object) and isentity(object) and self:find(object:GetModel()) then
    return true
  end
end

--- Supposed to allow the container props to be opened.
-- @param actor [Player]
-- @param entity [Entity]
-- @return [Boolean true for a container; currently always nil, as the body checks
--   an undefined 'object' variable instead of the entity]
function Container:CanEntityBeOpened(actor, entity)
  if IsValid(object) and isentity(object) and self:find(object:GetModel()) then
    return true
  end
end

Cable.receive('fl_container_open', function(actor, entity)
  local container_data = Container:find(entity:GetModel())

  if container_data and entity:GetClass() == 'prop_physics' then
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

    hook.Run('PreContainerOpen', entity)

    actor:open_inventory(entity.inventory, entity)
  end
end)
