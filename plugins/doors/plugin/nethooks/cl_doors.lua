--- Client-side network receivers of the Doors plugin: opens the context menu of a door when
-- the server sends it, and updates the door management menu with the state of the door that
-- the server answers with.

Cable.receive('fl_door_menu', function(entity, can_lock, conditions, info)
  Doors:open_menu(entity, can_lock, conditions, info)
end)

Cable.receive('fl_door_info', function(entity, info)
  local management = Doors.management

  if IsValid(management) and management:get_door() == entity and istable(info) then
    management:set_info(info)
  end
end)
