function Inventories:PostCreateCharacter(player, char, char_data)
  Plugin.call('AddDefaultItems', player, char, char.inventory)
end

function Inventories:PlayerDisconnected(player)
  player:delete_inventories()
end

function Inventories:OnActiveCharacterSet(player, character)
  player:delete_inventories()
  player:create_inventories()
end

function Inventories:CreatePlayerInventories(player, inventories)
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

  local equipment = Inventory.new()
    equipment.title = 'ui.inventory.equipment'
    equipment:set_size(Config.get('equipment_width'), Config.get('equipment_height'))
    equipment.type = 'equipment'
    equipment.multislot = false
  inventories[equipment.type] = equipment

  local pockets = Inventory.new()
    pockets.title = 'ui.inventory.pockets'
    pockets:set_size(1, Config.get('pockets_height'))
    pockets.type = 'pockets'
    pockets.infinite_width = true
    pockets.multislot = false
  inventories[pockets.type] = pockets
end

function Inventories:SaveCharacterData(player, char)
  if player:get_character_id() == char.id then
    char.item_ids = table.concat(player:get_items_list(), ',')
  end
end

function Inventories:PreItemSave(item_table, save_table)
  save_table.x = item_table.x
  save_table.y = item_table.y
  save_table.inventory_type = item_table.inventory_type
end

function Inventories:PlayerTakeItem(player, item_table, ...)
  if IsValid(item_table.entity) then
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

    inv_type = inv_type or item_table.preferred_inventory or player.default_inventory

    local success, error_text = player:add_item(item_table, inv_type)

    if success then
      player:sync_inventories()
      item_table.entity:Remove()
      Item.async_save_entities()

      hook.run('ItemTransferred', item_table, player:get_inventory(inv_type))
    else
      player:notify(error_text)
    end
  end
end

function Inventories:PlayerDropItem(player, instance_id)
  local item_table = Item.find_instance_by_id(instance_id)
  local trace = player:GetEyeTraceNoCursor()

  if hook.run('CanPlayerDropItem', player, item_table) == false then return end

  local inventory = Inventories.find(item_table.inventory_id)

  hook.run('ItemTransferred', item_table, nil, inventory)

  inventory:take_item_by_id(instance_id)
  inventory:sync()

  local distance = trace.HitPos:Distance(player:GetPos())

  if distance < 80 then
    Item.spawn(trace.HitPos, Angle(0, 0, 0), item_table)
  else
    local ent, item_table = Item.spawn(player:EyePos() + trace.Normal * 20, Angle(0, 0, 0), item_table)
    local phys_obj = ent:GetPhysicsObject()

    if IsValid(phys_obj) then
      phys_obj:ApplyForceCenter(trace.Normal * 200)
    end
  end

  Item.async_save_entities()
end

function Inventories:ItemTransferred(item_table, new_inventory, old_inventory)
  if item_table.on_transfer then
    item_table:on_transfer(new_inventory, old_inventory)
  end
end

function Inventories:CanItemMove(item_table, inventory, x, y)
  if item_table.can_move then
    local success, error_text = item_table:can_move(inventory, x, y)

    if success == false then
      return false, error_text
    end
  end
end

function Inventories:CanItemTransfer(item_table, inventory, x, y)
  local inv_type = inventory.type

  if inv_type == 'equipment' and (!item_table.equip_slot or item_table.equip_inv != 'equipment') then
    return false, 'error.inventory.cant_equip'
  end

  if inv_type == 'pockets' and !item_table.pocket_size then
    return false, 'error.inventory.too_big'
  end

  if item_table.can_transfer then
    local success, error_text = item_table:can_transfer(inventory, x, y)

    if success == false then
      return false, error_text
    end
  end
end

function Inventories:PlayerThrewGrenade(player, entity)
  if !IsValid(player) then return end

  local items = player:get_items()

  for k, v in pairs(items) do
    local item_table = Item.find_instance_by_id(v)

    if item_table:is('throwable') and item_table:is_equipped() then
      player:take_item_by_id(v)
    end
  end
end

function Inventories:PlayerUseItem(player, item_table, ...)
  if item_table.on_use then
    local result = item_table:on_use(player)

    if result == true then
      return
    elseif result == false then
      return false
    end
  end

  if IsValid(item_table.entity) then
    item_table.entity:Remove()
  else
    local inventory = Inventories.find(item_table.inventory_id)

    hook.run('ItemTransferred', item_table, nil, inventory)

    inventory:take_item_by_id(item_table.instance_id)
    inventory:sync()
  end
end

function Inventories:OnItemEquipped(player, item_table)
  if item_table:is('wearable') then
    Cable.send(player, 'fl_rebuild_player_panel')
  end
end

function Inventories:OnItemUnequipped(player, item_table)
  if item_table:is('wearable') then
    Cable.send(player, 'fl_rebuild_player_panel')
  end
end

Cable.receive('fl_item_move', function(player, instance_ids, inventory_id, x, y)
  local instance_id = instance_ids[1]
  local item_table = Item.find_instance_by_id(instance_id)
  local inventory = Inventories.find(inventory_id)

  if inventory_id == item_table.inventory_id then
    inventory:move_stack(instance_ids, x, y)
  else
    local old_inventory = Inventories.find(item_table.inventory_id)

    if #instance_ids == 1 then
      old_inventory:transfer_item(instance_id, inventory, x, y)
    else
      old_inventory:transfer_stack(instance_ids, inventory, x, y)
    end

    old_inventory:sync()
  end

  inventory:sync()

  hook.run('OnItemMoved', player, instance_ids, inventory_id, x, y)
end)

Cable.receive('fl_item_drop', function(player, instance_id)
  hook.run('PlayerDropItem', player, instance_id)
end)

Cable.receive('fl_inventory_close', function(player, inventory_id)
  local inventory = Inventories.find(inventory_id)
  inventory:remove_receiver(player)
  inventory:sync()

  hook.run('OnInventoryClosed', player, inventory)
end)

Cable.receive('fl_character_desc_change', function(player, text)
  if text:len() >= Config.get('character_min_desc_len') and text:len() <= Config.get('character_max_desc_len') then
    Characters.set_desc(player, text)
    player:notify('notification.char_desc_changed')
  end
end)
