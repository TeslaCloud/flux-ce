cable.receive('fl_door_menu', function(entity)
  local door_menu = vgui.create('fl_door_menu')
  door_menu:set_door(entity)
end)