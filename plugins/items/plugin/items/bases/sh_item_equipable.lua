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

--- Checks whether the item is in the inventory that it gets equipped in.
-- @return [Boolean]
function ItemEquipable:is_equipped()
  return self.inventory_type == self.equip_inv
end

--- Called on the server by the 'CanItemTransfer' hook before the item is moved to another
-- inventory. Prevents equipping the item if can_equip disallows it or its equipment slot
-- is occupied, and prevents unequipping it if can_unequip disallows it.
-- @param inventory [Inventory the inventory the item is being moved to]
-- @param x [Number target slot, or nil if the position is yet to be found]
-- @param y [Number target slot, or nil if the position is yet to be found]
-- @return [Boolean false to prevent the transfer, nil otherwise]
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

--- Called by ItemEquipable:can_transfer before the item is equipped.
-- Override it and return false to prevent the item from being equipped.
-- @param player [Player the player that has the item, or nil if no player has it]
-- @return [Boolean false to prevent equipping, nil otherwise]
function ItemEquipable:can_equip(player)
end

--- Called by ItemEquipable:can_transfer before the item is unequipped.
-- Override it and return false to prevent the item from being unequipped.
-- @param player [Player the player that has the item, or nil if no player has it]
-- @return [Boolean false to prevent unequipping, nil otherwise]
function ItemEquipable:can_unequip(player)
end

--- Called by ItemEquipable:equip when the item gets equipped.
-- Override it to apply the effects of the item to the player.
-- @param player [Player]
function ItemEquipable:post_equipped(player)
end

--- Called by ItemEquipable:equip when the item gets unequipped.
-- Override it to remove the effects of the item from the player.
-- @param player [Player]
function ItemEquipable:post_unequipped(player)
end

--- Applies or reverts the equipped state of the item; it does not move the item itself.
-- Empties and disables (or enables back) the inventories listed in disabled_inventories, calls
-- post_equipped or post_unequipped and runs the 'OnItemEquipped' or 'OnItemUnequipped' hook.
-- @param player [Player]
-- @param should_equip [Boolean true to equip the item, false to unequip it]
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

--- Called on the server by the 'PreItemTransfer' hook when the item is about to change its
-- inventory. Equips or unequips the item if it enters or leaves its equipment inventory.
-- @param new_inventory [Inventory where the item goes, or nil if it is dropped]
-- @param old_inventory [Inventory where the item was, or nil if it is picked up]
function ItemEquipable:on_transfer(new_inventory, old_inventory)
  if new_inventory and new_inventory.type == self.equip_inv then
    local player = new_inventory.owner
    player:EmitSound(self.action_sounds['equip'])
    self:equip(player, true)
  end

  if old_inventory and old_inventory.type == self.equip_inv then
    local player = old_inventory.owner
    player:EmitSound(self.action_sounds['unequip'])
    self:equip(player, false)
  end
end

--- Called on the server when a player presses the equip button in the item's menu.
-- Moves the item to its equipment inventory, or back to the main inventory
-- if it is equipped already. An item lying in the world is picked up and equipped.
-- @param player [Player]
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

--- Called on the server right after the player that has the item spawns.
-- Applies the equipped state again if the item is equipped.
-- @param player [Player]
function ItemEquipable:on_loadout(player)
  if self:is_equipped() then
    self:equip(player, true)
  end
end
