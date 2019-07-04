Cable.receive('fl_door_menu', function(entity, can_lock, conditions)
  if can_lock or can('manage_doors') then
    local menu = DermaMenu()
    local locked = entity:get_nv('fl_locked')

    if can_lock then
      menu:AddOption(locked and t'ui.door.unlock' or t'ui.door.lock', function()
        Cable.send('fl_lock_door', entity, !locked)
      end)
    end

    if can('manage_doors') then
      menu:AddOption(t'ui.door.settings', function()
        local door_menu = vgui.create('fl_door_menu')
        door_menu:set_door(entity, conditions)
      end)
    end

    if menu:ChildCount() < 1 then return end

    menu:Open()
    menu:Center()

    menu:MakePopup()
    menu:DoModal()
  end
end)
