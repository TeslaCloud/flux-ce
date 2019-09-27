function Inventories:PlayerBindPress(player, bind, pressed)
  if bind:find('slot') and pressed then
    local n = tonumber(bind:match('slot(%d+)'))

    if n then
      Plugin.call('PlayerSelectSlot', player, n)
    end
  end
end

function Inventories:PlayerSelectSlot(player, slot)
  if slot >= 1 and slot < 9 then
    local cur_time = CurTime()
    local instance_id = player:get_inventory('hotbar'):get_first_in_slot(slot, 1)
    local item_table = Item.find_by_instance_id(instance_id)

    if !player.next_slot_click or player.next_slot_click <= cur_time then
      if item_table then
        if item_table:is('weapon') or item_table:is('throwable') then
          local weapon = player:GetWeapon(item_table.weapon_class)

          if IsValid(weapon) then
            input.SelectWeapon(weapon)

            local active_weapon = player:GetActiveWeapon()

            if IsValid(active_weapon) and active_weapon != weapon then
              surface.PlaySound('common/wpn_select.wav')

              self:popup_hotbar()
            end
          end
        elseif !item_table:is('weapon') and item_table.on_use then
          item_table:do_menu_action('on_use')

          self:popup_hotbar()
        end
      else
        local weapon = player:GetWeapon('weapon_fists')

        if IsValid(weapon) then
          input.SelectWeapon(weapon)

          local active_weapon = player:GetActiveWeapon()

          if IsValid(active_weapon) and active_weapon != weapon then
            surface.PlaySound('common/wpn_hudoff.wav')

            self:popup_hotbar()
          end
        end
      end

      player.next_slot_click = cur_time + 0.2
    end
  end
end

function Inventories:GetInventorySize(player, inv_type)
  if inv_type == 'pockets' then
    local item_count = 1
    local max_x = 0

    for k, v in pairs(player:get_items(inv_type)) do
      local item_table = Item.find_instance_by_id(v)

      if item_table and item_table.inventory_type == 'pockets' then
        max_x = math.max(max_x, item_table.slot_id[2])
      end
    end

    return max_x + 1, Config.get('pockets_height')
  end
end
