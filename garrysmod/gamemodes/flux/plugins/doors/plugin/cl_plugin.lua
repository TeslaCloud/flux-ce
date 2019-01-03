cable.receive('fl_door_menu', function(entity, conditions)
  local door_menu = vgui.create('fl_door_menu')
  door_menu:set_door(entity, conditions)
end)