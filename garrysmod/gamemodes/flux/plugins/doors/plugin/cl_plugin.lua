cable.receive('fl_door_menu', function(entity, can_lock, conditions)
  local menu = DermaMenu()
  local locked = entity:get_nv('fl_locked')
  
  if can_lock then
    menu:AddOption(locked and 'Unlock' or 'Lock', function()
      cable.send('fl_lock_door', entity, !locked)
    end)
  end

  menu:AddOption('Settings', function()
    local door_menu = vgui.create('fl_door_menu')
    door_menu:set_door(entity, conditions)
  end)

  menu:Open()
  menu:Center()

  menu:MakePopup()
  menu:DoModal()
end)
