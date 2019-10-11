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
    equipment_accessories:set_size(2, 2)
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

function Inventories:SaveCharacterData(player, char)
  if player:get_character_id() == char.id then
    char.item_ids = table.concat(player:get_items_ids(), ',')
  end
end

function Inventories:PreItemSave(item_table, save_table)
  save_table.x = item_table.x
  save_table.y = item_table.y
  save_table.inventory_type = item_table.inventory_type
  save_table.rotated = item_table.rotated

  if item_table.inventory then
    save_table.items = item_table.inventory:get_items_ids()
  end
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

    local player_inventory = player:get_inventory(inv_type)

    hook.run('PreItemTransfer', item_table, player_inventory)

    local success, error_text = player:add_item(item_table, inv_type)

    if success then
      player:sync_inventories()
      item_table.entity:Remove()
      Item.async_save_entities()

      hook.run('ItemTransferred', item_table, player_inventory)
    else
      player:notify(error_text)
    end
  end
end

function Inventories:PlayerDropItem(player, instance_ids)
  if isnumber(instance_ids) then
    instance_ids = { instance_ids }
  end

  local trace = player:GetEyeTraceNoCursor()
  local first_item = Item.find_instance_by_id(table.first(instance_ids))
  local inventory = Inventories.find(first_item.inventory_id)
  local distance = trace.HitPos:Distance(player:GetPos())

  for k, v in pairs(instance_ids) do
    local item_table = Item.find_instance_by_id(v)

    if hook.run('CanPlayerDropItem', player, item_table) == false then return end

    hook.run('PreItemTransfer', item_table, nil, inventory)

    inventory:take_item_by_id(v)

    hook.run('ItemTransferred', item_table, nil, inventory)

    if distance < 80 then
      Item.spawn(trace.HitPos + Vector(0, 0, 5) * k, Angle(0, 0, 0), item_table)
    else
      local ent = Item.spawn(player:EyePos() + trace.Normal * 20 + VectorRand() * 5, Angle(0, 0, 0), item_table)
      local phys_obj = ent:GetPhysicsObject()

      if IsValid(phys_obj) then
        phys_obj:ApplyForceCenter(trace.Normal * 200)
      end
    end
  end

  inventory:sync()
  Item.async_save_entities()
end

function Inventories:PreItemTransfer(item_table, new_inventory, old_inventory)
  if item_table.on_transfer then
    item_table:on_transfer(new_inventory, old_inventory)
  end
end

function Inventories:ItemTransferred(item_table, new_inventory, old_inventory)
  local inventory = item_table.inventory

  if inventory then
    for k, v in ipairs(inventory.receivers) do
      if IsValid(v) and !v:has_item_by_id(item_table.instance_id) then
        Cable.send(v, 'fl_inventory_close', inventory.id)
      end
    end
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

  if inventory.instance_id then
    local item_container = Item.find_instance_by_id(inventory.instance_id)
    local success, error_text = item_container:can_contain(item_table)

    if success == false then
      return false, error_text
    end
  end
end

function Inventories:PlayerThrewGrenade(player, entity)
  if !IsValid(player) then return end

  for k, v in pairs(player:get_items()) do
    if v:is('throwable') and v:is_equipped() then
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

    hook.run('PreItemTransfer', item_table, nil, inventory)

    inventory:take_item_by_id(item_table.instance_id)
    inventory:sync()

    hook.run('ItemTransferred', item_table, nil, inventory)
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

function Inventories:OnItemCreated(item_table)
  item_table.rotated = false
end

Cable.receive('fl_item_move', function(player, instance_ids, inventory_id, x, y, was_rotated)
  local instance_id = instance_ids[1]
  local item_table = Item.find_instance_by_id(instance_id)
  local inventory = Inventories.find(inventory_id)

  if inventory_id == item_table.inventory_id then
    inventory:move_stack(instance_ids, x, y, was_rotated)
  else
    local old_inventory = Inventories.find(item_table.inventory_id)

    if #instance_ids == 1 then
      old_inventory:transfer_item(instance_id, inventory, x, y, was_rotated)
    else
      old_inventory:transfer_stack(instance_ids, inventory, x, y, was_rotated)
    end

    old_inventory:sync()
  end

  inventory:sync()

  hook.run('OnItemMoved', player, instance_ids, inventory_id, x, y)
end)

Cable.receive('fl_item_drop', function(player, instance_ids)
  hook.run('PlayerDropItem', player, instance_ids)
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
