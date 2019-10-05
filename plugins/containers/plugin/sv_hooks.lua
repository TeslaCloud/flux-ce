function Container:PlayerUse(player, entity)
  local cur_time = CurTime()

  if !player.next_cont_use or player.next_cont_use <= cur_time then
    local container_data = self:find(entity:GetModel())

    if container_data and entity:GetClass() == 'prop_physics' then
      if !entity.inventory then
        local inventory = Inventory.new()
        inventory:set_size(container_data.w, container_data.h)
        inventory.title = container_data.name
        inventory.type = 'container'
        inventory.multislot = (container_data != nil) and true or false
        inventory.entity = entity

        if entity.items then
          inventory:load_items(entity.items)

          entity.items = nil
        end

        entity.inventory = inventory
      end

      if container_data.open_sound then
        entity:EmitSound(container_data.open_sound, 55)
      end

      player:open_inventory(entity.inventory)

      player.next_cont_use = cur_time + 1
    end
  end
end

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

function Container:PlayerSpawnedProp(player, model, entity)
  if self:find(model)then
    entity:SetPersistent(true)
  end
end

function Container:OnInventoryClosed(player, inventory)
  local entity = inventory.entity

  if IsValid(entity) then
    local container_data = self:find(entity:GetModel())

    if container_data and container_data.close_sound then
      entity:EmitSound(container_data.close_sound, 55)
    end
  end
end

function Container:PrePersistenceSave()
  for k, v in ipairs(ents.all()) do
    if v.inventory and self:find(v:GetModel()) then
      v.items = v.inventory:get_items_ids()
      v.inventory = nil
    end
  end
end
