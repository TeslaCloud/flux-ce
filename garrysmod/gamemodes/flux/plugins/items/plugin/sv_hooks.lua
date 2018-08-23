function flItems:InitPostEntity()
  item.Load()
end

function flItems:SaveData()
  item.SaveAll()
end

function flItems:ClientIncludedSchema(player)
  item.SendToPlayer(player)
end

function flItems:PlayerUseItemEntity(player, entity, itemTable)
  netstream.Start(player, "PlayerUseItemEntity", entity)
end

function flItems:PlayerTakeItem(player, itemTable, ...)
  if (IsValid(itemTable.entity)) then
    itemTable.entity:Remove()
    player:GiveItemByID(itemTable.instance_id)
    item.AsyncSaveEntities()
  end
end

function flItems:PlayerDropItem(player, instance_id)
  local itemTable = item.FindInstanceByID(instance_id)
  local trace = player:GetEyeTraceNoCursor()

  if (itemTable.on_drop) then
    local result = itemTable:on_drop(player)

    if (result == false) then
      return false
    end
  end

  player:TakeItemByID(instance_id)

  local distance = trace.HitPos:Distance(player:GetPos())

  if (distance < 80) then
    item.Spawn(trace.HitPos, Angle(0, 0, 0), itemTable)
  else
    item.Spawn(player:EyePos() + trace.Normal * 15, Angle(0, 0, 0), itemTable)
  end

  item.AsyncSaveEntities()
end

function flItems:PlayerUseItem(player, itemTable, ...)
  if (itemTable.on_use) then
    local result = itemTable:on_use(player)

    if (result == true) then
      return
    elseif (result == false) then
      return false
    end
  end

  if (IsValid(itemTable.entity)) then
    itemTable.entity:Remove()
  else
    player:TakeItemByID(itemTable.instance_id)
  end
end

function flItems:OnItemGiven(player, itemTable, slot)
  hook.Run("PlayerInventoryUpdated", player)
end

function flItems:OnItemTaken(player, itemTable, slot)
  hook.Run("PlayerInventoryUpdated", player)
end

function flItems:PlayerInventoryUpdated(player)
  netstream.Start(player, "RefreshInventory")
end

function flItems:PlayerCanUseItem(player, itemTable, action, ...)
  local trace = player:GetEyeTraceNoCursor()

  if ((!player:HasItemByID(itemTable.instance_id) and !IsValid(itemTable.entity)) or (IsValid(itemTable.entity) and trace.Entity and trace.Entity != itemTable.entity)) then
    return false
  end
end

function flItems:PostCharacterLoaded(player, character)
  local playerInv = player:GetInventory()

  for slot, ids in ipairs(playerInv) do
    for k, v in ipairs(ids) do
      local itemTable = item.FindInstanceByID(v)

      if (istable(itemTable)) then
        itemTable:on_loadout(player)
      end
    end
  end
end

function flCharacters:PreSaveCharacter(player, index)
  local playerInv = player:GetInventory()

  for slot, ids in ipairs(playerInv) do
    for k, v in ipairs(ids) do
      local itemTable = item.FindInstanceByID(v)

      itemTable:on_save(player)
    end
  end
end

netstream.Hook("PlayerDropItem", function(player, instance_id)
  hook.Run("PlayerDropItem", player, instance_id)
end)

netstream.Hook("Flux::Items::AbortHoldStart", function(player)
  local ent = player:GetNetVar("HoldEnt")

  if (IsValid(ent)) then
    ent:SetNetVar("LastActivator", false)
  end

  player:SetNetVar("HoldStart", false)
  player:SetNetVar("HoldEnt", false)
end)
