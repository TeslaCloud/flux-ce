function Items:InitPostEntity()
  item.load()
end

function Items:SaveData()
  item.save_all()
end

function Items:ClientIncludedSchema(player)
  item.send_to_player(player)
end

function Items:PlayerUseItemEntity(player, entity, item_table)
  cable.send(player, 'PlayerUseItemEntity', entity)
end

function Items:PlayerTakeItem(player, item_table, ...)
  if IsValid(item_table.entity) then
    local success = player:give_item_by_id(item_table.instance_id)

    if success then
      item_table.entity:Remove()
      item.async_save_entities()
    end
  end
end

function Items:PlayerDropItem(player, instance_id)
  local item_table = item.find_instance_by_id(instance_id)
  local trace = player:GetEyeTraceNoCursor()

  if item_table.on_drop then
    local result = item_table:on_drop(player)

    if result == false then
      return false
    end
  end

  player:take_item_by_id(instance_id)

  local distance = trace.HitPos:Distance(player:GetPos())

  if distance < 80 then
    item.spawn(trace.HitPos, Angle(0, 0, 0), item_table)
  else
    local ent, item_table = item.spawn(player:EyePos() + trace.Normal * 20, Angle(0, 0, 0), item_table)
    local phys_obj = ent:GetPhysicsObject()

    if IsValid(phys_obj) then
      phys_obj:ApplyForceCenter(trace.Normal * 200)
    end
  end

  item.async_save_entities()
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

function Items:OnItemGiven(player, item_table, slot)
  hook.run('PlayerInventoryUpdated', player)
end

function Items:OnItemTaken(player, item_table, slot)
  hook.run('PlayerInventoryUpdated', player)
end

function Items:PlayerInventoryUpdated(player)
  cable.send(player, 'RefreshInventory')
end

function Items:PlayerCanUseItem(player, item_table, action, ...)
  local trace = player:GetEyeTraceNoCursor()

  if (!player:has_item_by_id(item_table.instance_id) and !IsValid(item_table.entity)) or (IsValid(item_table.entity) and trace.Entity and trace.Entity != item_table.entity) then
    return false
  end
end

function Items:PostCharacterLoaded(player, character)
  local ply_inv = player:get_inventory()

  for slot, ids in ipairs(ply_inv) do
    for k, v in ipairs(ids) do
      local item_table = item.find_instance_by_id(v)

      if istable(item_table) then
        item_table:on_loadout(player)
      end
    end
  end
end

function Characters:PreSaveCharacter(player, index)
  local ply_inv = player:get_inventory()

  for slot, ids in ipairs(ply_inv) do
    for k, v in ipairs(ids) do
      local item_table = item.find_instance_by_id(v)

      item_table:on_save(player)
    end
  end
end

cable.receive('PlayerDropItem', function(player, instance_id)
  hook.run('PlayerDropItem', player, instance_id)
end)

cable.receive('Flux::Items::AbortHoldStart', function(player)
  local ent = player:get_nv('hold_entity')

  if IsValid(ent) then
    ent:set_nv('last_activator', false)
  end

  player:set_nv('hold_start', false)
  player:set_nv('hold_entity', false)
end)
