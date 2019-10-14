class 'ItemEquipable' extends 'ItemBase'

ItemEquipable.name = 'Equipment Base'
ItemEquipable.description = 'An item that can be equipped.'
ItemEquipable.category = 'item.category.equipment'
ItemEquipable.stackable = false
ItemEquipable.equip_slot = 'item.slot.accessory'
ItemEquipable.equip_inv = 'hotbar'
ItemEquipable.disabled_inventories = {}
ItemEquipable.action_sounds = {
  ['equip'] = 'items/battery_pickup.wav',
  ['unequip'] = 'items/battery_pickup.wav'
}

ItemEquipable:add_button('equip', {
  get_name = function(item_obj)
    return item_obj:is_equipped() and 'item.option.unequip' or 'item.option.equip'
  end,
  icon = 'icon16/user_suit.png',
  callback = 'on_equip'
})

function ItemEquipable:is_equipped()
  return self.inventory_type == self.equip_inv
end

function ItemEquipable:can_transfer(inventory, x, y)
  local player = self:get_player()
  local inv_type = inventory.type

  if inv_type == self.equip_inv then
    if self:can_equip(player) == false then
      return false
    end

    for k, v in pairs(inventory:get_items()) do
      if v.equip_slot and v:is_equipped() and v.instance_id != self.instance_id then
        if v.equip_slot == self.equip_slot then
          return false
        elseif istable(self.equip_slot) then
          for k1, v1 in pairs(self.equip_slot) do
            if v1 == v.equip_slot then
              return false
            elseif istable(v.equip_slot) then
              for k2, v2 in pairs(v.equip_slot) do
                if v1 == v2 then
                  return false
                end
              end
            end
          end
        end
      end
    end
  elseif inv_type != self.equip_inv and self.inventory_type == self.equip_inv then
    if self:can_unequip(player) == false then
      return false
    end
  end
end

function ItemEquipable:can_equip(player)
end

function ItemEquipable:can_unequip(player)
end

function ItemEquipable:post_equipped(player)
end

function ItemEquipable:post_unequipped(player)
end

function ItemEquipable:equip(player, should_equip)
  if should_equip then
    for k, v in pairs(self.disabled_inventories) do
      local inventory = player:get_inventory(v)

      if inventory then
        for k1, v1 in pairs(inventory:get_items()) do
          local success, error_text = player:transfer_item(v1.instance_id, 'main_inventory')

          if !success then
            player:notify(error_text)

            return
          end
        end

        inventory:set_disabled(true)
      end
    end

    self:post_equipped(player)

    hook.run('OnItemEquipped', player, self)
  else
    for k, v in pairs(self.disabled_inventories) do
      local inventory = player:get_inventory(v)

      if inventory then
        inventory:set_disabled(false)
      end
    end

    self:post_unequipped(player)

    hook.run('OnItemUnequipped', player, self)
  end
end

function ItemEquipable:on_transfer(new_inventory, old_inventory)
  if new_inventory and new_inventory.type == self.equip_inv then
    local player = new_inventory.owner
    player:EmitSound(self.action_sounds['equip'])
    self:equip(player, true)
  elseif old_inventory and old_inventory.type == self.equip_inv then
    local player = old_inventory.owner
    player:EmitSound(self.action_sounds['unequip'])
    self:equip(player, false)
  end
end

function ItemEquipable:on_equip(player)
  if IsValid(self.entity) then
    self:do_menu_action('on_take', player, { inv_type = self.equip_inv })
  else
    if self:is_equipped() then
      player:transfer_item(self.instance_id, 'main_inventory')
    else
      player:transfer_item(self.instance_id, self.equip_inv)
    end
  end
end

function ItemEquipable:on_loadout(player)
  if self:is_equipped() then
    self:equip(player, true)
  end
end
