function Container:PlayerUse(player, entity)
  local cur_time = CurTime()

  if !player.next_cont_use or player.next_cont_use <= cur_time then
    local container_data = Container:all()[entity:GetModel()]

    if container_data and entity:GetClass() == 'prop_physics' then
      container_data.w = container_data.w or 4
      container_data.h = container_data.h or 4

      if !entity.inventory then
        local inventory = {}

        for i = 1, container_data.h do
          inventory[i] = {}

          for k = 1, container_data.w do
            inventory[i][k] = {}
          end
        end

        inventory.width, inventory.height = container_data.w, container_data.h
        inventory.type = 'container'

        entity.inventory = inventory
      end

      for i = 1, container_data.h do
        for k = 1, container_data.w do
          if entity.inventory[i][k] then
            for k1, v1 in pairs(entity.inventory[i][k]) do
              local item_table = Item.find_instance_by_id(v1)

              item_table.inventory_entity = entity

              Item.network_item(player, v1)
            end
          end
        end
      end

      if container_data.open_sound then
        entity:EmitSound(container_data.open_sound, 55)
      end

      entity:set_nv('inventory', entity.inventory)

      entity.receivers = entity.receviers or {}

      table.insert(entity.receivers, player)

      Cable.send(player, 'fl_open_container', entity)

      player.next_cont_use = cur_time + 1
    end
  end
end

function Container:EntityRemoved(entity)
  if entity.receviers then
    for k, v in ipairs(entity.receivers) do
      if IsValid(v) then
        Cable.send(v, 'fl_close_container')
      end
    end
  end
end

function Container:PlayerSpawnedProp(player, model, entity)
  if Container:all()[model] then
    entity:SetPersistent(true)
  end
end

function Container:CanItemStack(player, item_table, inv_type, x, y)
  if inv_type == 'container' then
    local inv_ent = item_table.inventory_entity

    if IsValid(inv_ent) then
      local ent_inv = inv_ent:get_nv('inventory')
      local ids = ent_inv[y][x]

      if #ids == 0 then
        return true
      end
    end
  end
end

function Container:CanPlayerDropItem(player, item_table)
  if item_table.inventory_type == 'container' then
    return false
  end
end

function Container:CanItemMoveToContainer(player, item_table, inv_type, x, y, entity)
  if inv_type == 'container' then
    local ent_inv = entity:get_nv('inventory')
    local ids = ent_inv and ent_inv[y][x]

    if ids then
      if #ids == 0 then
        return true
      end

      local slot_table = Item.find_instance_by_id(ids[1])

      if item_table.id != slot_table.id or #ids >= item_table.max_stack then
        return false
      end
    end

    if item_table.can_stack then
      if item_table:can_stack(player, inv_type, x, y) == false then
        return false
      end
    end
  end
end

function Container:ItemContainerMove(player, instance_ids, inv_type, x, y, entity)
  local ent_inv
  local old_inv_type
  local ply_inv

  if IsValid(entity) then
    ent_inv = entity:get_nv('inventory')
  end

  for k, v in pairs(instance_ids) do
    local item_table = Item.find_instance_by_id(v)

    if hook.run('CanItemMoveToContainer', player, item_table, inv_type, x, y, entity) == false or
       hook.run('CanItemTransfer', player, item_table, inv_type, x, y) == false or
       hook.run('CanItemMove', player, item_table, inv_type, x, y) == false or
       hook.run('CanItemStack', player, item_table, inv_type, x, y) == false then
      return
    end

    local old_y, old_x = unpack(item_table.slot_id)
    old_inv_type = item_table.inventory_type

    if IsValid(item_table.inventory_entity) then
      entity = item_table.inventory_entity
      ent_inv = item_table.inventory_entity:get_nv('inventory')
    end

    ply_inv = player:get_inventory(inv_type != 'container' and inv_type or old_inv_type)

    item_table.slot_id = { y, x }

    if inv_type == old_inv_type then
      table.insert(ent_inv[y][x], v)
      table.remove_by_value(ent_inv[old_y][old_x], v)
    else
      if inv_type == 'container' then
        table.insert(ent_inv[y][x], v)
        table.remove_by_value(ply_inv[old_y][old_x], v)

        item_table.inventory_entity = entity
      else
        table.insert(ply_inv[y][x], v)
        table.remove_by_value(ent_inv[old_y][old_x], v)

        item_table.inventory_entity = nil
      end

      item_table.inventory_type = inv_type

      hook.run('OnItemInventoryChanged', player, item_table, inv_type, old_inv_type)
      player:set_inventory(ply_inv, inv_type != 'container' and inv_type or old_inv_type)
    end

    if IsValid(entity) then
      for k1, v1 in ipairs(entity.receivers) do
        if IsValid(v1) then
          Item.network_item(v1, v)
        end
      end
    end
  end

  entity.inventory = ent_inv
  entity:set_nv('inventory', ent_inv)

  for k, v in ipairs(entity.receivers) do
    if IsValid(v) then
      Cable.send(v, 'fl_inventory_refresh', inv_type, old_inv_type)
    end
  end
end

Cable.receive('fl_item_container_move', function(player, instance_ids, inv_type, x, y, entity)
  hook.run('ItemContainerMove', player, instance_ids, inv_type, x, y, entity)
end)

Cable.receive('fl_container_closed', function(player, entity)
  local container_data = Container.all()[entity:GetModel()]

  if container_data.close_sound then
    entity:EmitSound(container_data.close_sound, 55)
  end

  if entity.receviers then
    table.remove_by_value(entity.receviers, player)
  end
end)
