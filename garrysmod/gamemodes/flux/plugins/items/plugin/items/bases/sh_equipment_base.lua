if !ItemUsable then
  util.include('sh_usable_base.lua')
end

-- Alternatively, you can use item.create_base('ItemEquippable')
class 'ItemEquippable' extends 'ItemUsable'

ItemEquippable.name = 'Equipment Base'
ItemEquippable.description = 'An item that can be equipped.'
ItemEquippable.category = t'item.category.equipment'
ItemEquippable.stackable = false
ItemEquippable.equip_slot = 'item.slot.accessory'
ItemEquippable.equip_inv = 'hotbar'
ItemEquippable.action_sounds = {
  ['equip'] = 'items/battery_pickup.wav',
  ['unequip'] = 'items/battery_pickup.wav'
}

if CLIENT then
  function ItemEquippable:get_use_text()
    if self:is_equipped() then
      return t'item.option.unequip'
    else
      return t'item.option.equip'
    end
  end

  function ItemEquippable:is_action_visible(act)
    if act == 'use' and IsValid(self.entity) then
      return false
    end
  end
end

function ItemEquippable:is_equipped()
  return self.inventory_type == self.equip_inv
end

function ItemEquippable:can_transfer(player, inv_type, x, y)
  if inv_type == self.equip_inv then
    for k, v in pairs(player:get_items(self.equip_inv)) do
      local item_table = item.find_instance_by_id(v)

      if item_table.equip_slot and item_table.equip_slot == self.equip_slot and item_table:is_equipped() and item_table.instance_id != self.instance_id then
        return false
      end
    end
  end
end

function ItemEquippable:can_equip(player) end
function ItemEquippable:can_unequip(player) end
function ItemEquippable:post_equipped(player) end
function ItemEquippable:post_unequipped(player) end

function ItemEquippable:equip(player, should_equip)
  if should_equip then
    if self:can_equip(player) != false then
      self:post_equipped(player)
    end
  else
    if self:can_unequip(player) != false then
      self:post_unequipped(player)
    end
  end
end

function ItemEquippable:on_inventory_changed(player, new_inv, old_inv)
  if IsValid(player) then
    if new_inv == self.equip_inv then
      self:equip(player, true)
      player:EmitSound(self.action_sounds['equip'])
    elseif old_inv == self.equip_inv then
      self:equip(player, false)
      player:EmitSound(self.action_sounds['unequip'])
    end
  end
end

function ItemEquippable:on_use(player)
  if IsValid(self.entity) then
    self:do_menu_action('on_take', player, { inv_type = self.equip_inv })
  else
    if self:is_equipped() then
      player:transfer_item(self.instance_id, 'main_inventory')
    else
      player:transfer_item(self.instance_id, self.equip_inv)
    end
  end

  return true
end

function ItemEquippable:on_drop(player)
  if self:is_equipped() then
    self:equip(player, false)
  end
end

function ItemEquippable:on_loadout(player)
  if self:is_equipped() then
    self:equip(player, true)
  end
end

ItemEquippable = ItemEquippable
