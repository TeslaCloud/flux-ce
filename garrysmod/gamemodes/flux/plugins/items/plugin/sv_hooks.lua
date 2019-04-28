function Items:InitPostEntity()
  Item.load()
end

function Items:OnEntityCreated(entity)
  if entity:GetClass() == 'npc_grenade_frag' then
    local player = entity:GetOwner()

    hook.run('PlayerThrewGrenade', player, entity)
  end
end

function Items:SaveData()
  Item.save_all()
end

function Items:ClientIncludedSchema(player)
  Item.send_to_player(player)
end

function Items:PlayerUseItemEntity(player, entity, item_table)
  Cable.send(player, 'fl_player_use_item_entity', entity)
end

function Items:PlayerTakeItem(player, item_table, ...)
  if IsValid(item_table.entity) then
    local inv_type

    for k, v in pairs({...}) do
      if istable(v) and k == 'inv_type' then
        inv_type = v
      end
    end

    local success = player:give_item_by_id(item_table.instance_id)

    if success then
      item_table.entity:Remove()
      Item.async_save_entities()
    end
  end
end

function Items:PlayerDropItem(player, instance_id)
  local item_table = Item.find_instance_by_id(instance_id)
  local trace = player:GetEyeTraceNoCursor()

  if hook.run('CanPlayerDropItem', player, item_table) == false then return end

  player:take_item_by_id(instance_id)

  item_table.inventory_type = nil
  item_table.slot_id = nil

  Item.network_item(player, instance_id)

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

function Items:PlayerUseItem(player, item_table, ...)
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
    player:take_item_by_id(item_table.instance_id)
  end
end

function Items:OnItemGiven(player, item_table, x, y)
  hook.run('OnItemInventoryChanged', player, item_table, item_table.inventory_type)

  Item.network_item(player, item_table.instance_id)

  hook.run('PlayerInventoryUpdated', player, item_table.inventory_type)
end

function Items:OnItemTaken(player, item_table, inv_type, slot_x, slot_y)
  hook.run('OnItemInventoryChanged', player, item_table, nil, inv_type)

  Item.network_item(player, item_table.instance_id)

  hook.run('PlayerInventoryUpdated', player, inv_type)
end

function Items:PlayerInventoryUpdated(player, inv_type)
  Cable.send(player, 'fl_inventory_refresh', inv_type)
end

function Items:PlayerCanUseItem(player, item_table, action, ...)
  local trace = player:GetEyeTraceNoCursor()

  if (!player:has_item_by_id(item_table.instance_id) and !IsValid(item_table.entity)) or
  (IsValid(item_table.entity) and trace.Entity and trace.Entity != item_table.entity) then
    return false
  end
end

function Items:CanPlayerDropItem(player, item_table)
  if istable(item_table) and item_table.on_drop then
    if item_table:on_drop(player) == false then
      return false
    end
  end
end

function Items:PostCharacterLoaded(player, character)
  local ply_inv = player:get_inventory()

  for slot, ids in ipairs(ply_inv) do
    for k, v in ipairs(ids) do
      local item_table = Item.find_instance_by_id(v)

      if istable(item_table) then
        item_table:on_loadout(player)
      end
    end
  end
end

function Items:PreSaveCharacter(player, index)
  local ply_inv = player:get_inventory()

  for k, v in ipairs(player:get_nv('inventory', {})) do
    for k1, v1 in ipairs(v) do
      for k2, v2 in ipairs(v1) do
        local item_table = Item.find_instance_by_id(v2)

        item_table:on_save(player)
      end
    end
  end
end

Cable.receive('fl_player_drop_item', function(player, instance_id)
  hook.run('PlayerDropItem', player, instance_id)
end)

Cable.receive('fl_items_abort_hold_start', function(player)
  local ent = player:get_nv('hold_entity')

  if IsValid(ent) then
    ent:set_nv('last_activator', false)
  end

  player:set_nv('hold_start', false)
  player:set_nv('hold_entity', false)
end)
