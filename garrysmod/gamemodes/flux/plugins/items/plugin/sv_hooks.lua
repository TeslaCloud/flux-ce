function flItems:InitPostEntity()
  item.Load()
end

function flItems:SaveData()
  item.SaveAll()
end

function flItems:ClientIncludedSchema(player)
  item.SendToPlayer(player)
end

function flItems:PlayerUseItemEntity(player, entity, item_table)
  cable.send(player, 'PlayerUseItemEntity', entity)
end

function flItems:PlayerTakeItem(player, item_table, ...)
  if IsValid(item_table.entity) then
    local success = player:GiveItemByID(item_table.instance_id)

    if success then
      item_table.entity:Remove()
      item.AsyncSaveEntities()
    end
  end
end

function flItems:PlayerDropItem(player, instance_id)
  local item_table = item.FindInstanceByID(instance_id)
  local trace = player:GetEyeTraceNoCursor()

  if item_table.on_drop then
    local result = item_table:on_drop(player)

    if result == false then
      return false
    end
  end

  player:TakeItemByID(instance_id)

  local distance = trace.HitPos:Distance(player:GetPos())

  if distance < 80 then
    item.Spawn(trace.HitPos, Angle(0, 0, 0), item_table)
  else
    local ent, item_table = item.Spawn(player:EyePos() + trace.Normal * 20, Angle(0, 0, 0), item_table)
    local phys_obj = ent:GetPhysicsObject()
    if IsValid(phys_obj) then
      phys_obj:ApplyForceCenter(trace.Normal * 200)
    end
  end

  item.AsyncSaveEntities()
end

function flItems:PlayerUseItem(player, item_table, ...)
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
    player:TakeItemByID(item_table.instance_id)
  end
end

function flItems:OnItemGiven(player, item_table, slot)
  hook.run('PlayerInventoryUpdated', player)
end

function flItems:OnItemTaken(player, item_table, slot)
  hook.run('PlayerInventoryUpdated', player)
end

function flItems:PlayerInventoryUpdated(player)
  cable.send(player, 'RefreshInventory')
end

function flItems:PlayerCanUseItem(player, item_table, action, ...)
  local trace = player:GetEyeTraceNoCursor()

  if (!player:HasItemByID(item_table.instance_id) and !IsValid(item_table.entity)) or (IsValid(item_table.entity) and trace.Entity and trace.Entity != item_table.entity) then
    return false
  end
end

function flItems:PostCharacterLoaded(player, character)
  local ply_inv = player:GetInventory()

  for slot, ids in ipairs(ply_inv) do
    for k, v in ipairs(ids) do
      local item_table = item.FindInstanceByID(v)

      if istable(item_table) then
        item_table:on_loadout(player)
      end
    end
  end
end

function flCharacters:PreSaveCharacter(player, index)
  local ply_inv = player:GetInventory()

  for slot, ids in ipairs(ply_inv) do
    for k, v in ipairs(ids) do
      local item_table = item.FindInstanceByID(v)

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
