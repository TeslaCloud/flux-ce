function PLUGIN:ShowSpare1(player)
  local trace = player:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if IsValid(entity) and entity:is_door() then
    cable.send(player, 'fl_door_menu', entity, entity.conditions)
  end
end

function PLUGIN:PlayerCanLockDoor(player, entity)
  local conditions = entity.conditions

  if conditions then
    for k, v in pairs(conditions) do
      local condition_table = Doors.conditions[v.id]

      if condition_table.check and condition_table.check(player, v.data) then
        return true
      end
    end
  end
end