function PLUGIN:ShowSpare1(player)
  local trace = player:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if IsValid(entity) and entity:is_door() then
    local can_lock = hook.run('PlayerCanLockDoor', player, entity)

    cable.send(player, 'fl_door_menu', entity, can_lock, entity.conditions)
  end
end

function PLUGIN:PlayerCanLockDoor(player, entity)
  local conditions = entity.conditions

  if conditions and Conditions:check(player, conditions) then
    return true
  end
end
