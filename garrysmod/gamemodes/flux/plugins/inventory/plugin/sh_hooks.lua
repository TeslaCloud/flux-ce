function fl_inventory:PlayerBindPress(player, bind, pressed)
  if bind:find('slot') and pressed then
    local n = tonumber(bind:match('slot(%d+)'))

    if n then
      plugin.call('PlayerSelectSlot', player, n)
    end
  end
end

function fl_inventory:PlayerSelectSlot(player, slot)
  local instance_id = player:get_first_in_slot(slot)
  local item_table = item.FindByInstanceID(instance_id)

  if item_table then
    item_table:do_menu_action("on_use")
  end
end
