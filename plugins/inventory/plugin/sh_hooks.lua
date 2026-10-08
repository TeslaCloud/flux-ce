--- Shared hooks of the Inventory plugin: turns the slot binds into the `PlayerSelectSlot`
-- hook, which selects the weapon of the item in that hotbar slot or uses the item, and
-- answers the `GetInventorySize` hook for the pockets.

--- Calls the 'PlayerSelectSlot' plugin hook when the player presses one of the slot binds.
-- @param client [Player]
-- @param bind [String]
-- @param pressed [Boolean]
function Inventories:PlayerBindPress(client, bind, pressed)
  if bind:find('slot') and pressed then
    local n = tonumber(bind:match('slot(%d+)'))

    if n then
      --- Called on the client when the local player presses one of the slot binds, `slot1`
      -- and so on. The Inventory plugin handles it by selecting the weapon of the item in
      -- that hotbar slot, or using the item. It is run with `Plugin.call`, so gamemode
      -- functions do not receive it.
      -- @param client [Player The local player]
      -- @param slot [Number Number of the slot taken from the bind]
      -- @realm [client]
      Plugin.call('PlayerSelectSlot', client, n)
    end
  end
end

--- Selects the weapon of the item in the specified hotbar slot, or uses the item
-- if it is not an equipable one. Switches to fists if the slot is empty.
-- @param client [Player]
-- @param slot [Number hotbar slot from 1 to 8]
function Inventories:PlayerSelectSlot(client, slot)
  if slot >= 1 and slot < 9 then
    local cur_time = CurTime()
    local instance_id = client:get_inventory('hotbar'):get_first_in_slot(slot, 1)
    local item_obj = Item.find_by_instance_id(instance_id)

    if !client.next_slot_click or client.next_slot_click <= cur_time then
      if item_obj then
        if item_obj:is('weapon') or item_obj:is('throwable') then
          local weapon = client:GetWeapon(item_obj.weapon_class)

          if IsValid(weapon) then
            input.SelectWeapon(weapon)

            local active_weapon = client:GetActiveWeapon()

            if IsValid(active_weapon) and active_weapon != weapon then
              surface.PlaySound('common/wpn_select.wav')

              self:popup_hotbar()
            end
          end
        elseif !item_obj:is('equipable') and item_obj.on_use then
          item_obj:do_menu_action('on_use')

          self:popup_hotbar()
        end
      else
        local weapon = client:GetWeapon('weapon_fists')

        if IsValid(weapon) then
          input.SelectWeapon(weapon)

          local active_weapon = client:GetActiveWeapon()

          if IsValid(active_weapon) and active_weapon != weapon then
            surface.PlaySound('common/wpn_hudoff.wav')

            self:popup_hotbar()
          end
        end
      end

      client.next_slot_click = cur_time + 0.2
    end
  end
end

--- Calculates the size of the pockets inventory based on the items in it.
-- @param owner [Player]
-- @param inv_type [String]
-- @return [Number width, Number height; nothing for any inventory other than pockets]
function Inventories:GetInventorySize(owner, inv_type)
  if inv_type == 'pockets' then
    local item_count = 1
    local max_x = 0

    for k, v in pairs(owner:get_items(inv_type)) do
      local item_obj = Item.find_instance_by_id(v)

      if item_obj and item_obj.inventory_type == 'pockets' then
        max_x = math.max(max_x, item_obj.slot_id[2])
      end
    end

    return max_x + 1, Config.get('pockets_height')
  end
end
