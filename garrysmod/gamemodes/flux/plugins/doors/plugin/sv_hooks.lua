function PLUGIN:ShowSpare1(player)
  local trace = player:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if IsValid(entity) and entity:is_door() then
    cable.send(player, 'fl_door_menu', entity)
  end
end