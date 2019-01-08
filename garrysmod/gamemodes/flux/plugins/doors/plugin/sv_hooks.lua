function PLUGIN:ShowSpare1(player)
  local trace = player:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if IsValid(entity) and entity:is_door() then
    local can_lock = hook.run('PlayerCanLockDoor', player, entity)

    cable.send(player, 'fl_door_menu', entity, can_lock, entity.conditions)
  end
end

local function CheckConditions(player, entity, conditions)
  for k, v in pairs(conditions) do
    local condition_table = Doors.conditions[v.id]

    if condition_table.check and condition_table.check(player, entity, v.data) == false or
    #v.childs != 0 and CheckConditions(player, entity, v.childs) == false then
      continue
    end

    return true
  end

  return false
end

function PLUGIN:PlayerCanLockDoor(player, entity)
  local conditions = entity.conditions

  if conditions then
    return CheckConditions(player, entity, conditions)
  end
end
