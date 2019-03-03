function Inventory:PlayerBindPress(player, bind, pressed)
  if bind:find('slot') and pressed then
    local n = tonumber(bind:match('slot(%d+)'))

    if n then
      plugin.call('PlayerSelectSlot', player, n)
    end
  end
end

function Inventory:PlayerSelectSlot(player, slot)
  local cur_time = CurTime()
  local instance_id = player:get_first_in_slot(slot, 1)
  local item_table = item.find_by_instance_id(instance_id)

  if !player.next_slot_click or player.next_slot_click <= cur_time then
    if item_table then
      if item_table.weapon_class then
        local weapon = player:GetWeapon(item_table.weapon_class)

        if IsValid(weapon) then
          input.SelectWeapon(weapon)

          local active_weapon = player:GetActiveWeapon()

          if IsValid(active_weapon) and active_weapon != weapon then
            surface.PlaySound('common/wpn_select.wav')
          end
        end
      else
        item_table:do_menu_action('on_use')
      end
    else
      local weapon = player:GetWeapon('weapon_fists')

      if IsValid(weapon) then
        input.SelectWeapon(weapon)

        local active_weapon = player:GetActiveWeapon()

        if IsValid(active_weapon) and active_weapon != weapon then
          surface.PlaySound('common/wpn_hudoff.wav')
        end
      end
    end

    player.next_slot_click = cur_time + 0.2
  end
end
