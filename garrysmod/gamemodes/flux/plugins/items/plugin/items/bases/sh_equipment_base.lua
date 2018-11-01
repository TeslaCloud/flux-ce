if !ItemUsable then
  util.include('sh_usable_base.lua')
end

-- Alternatively, you can use item.create_base('ItemEquippable')
class 'ItemEquippable' extends 'ItemUsable'

ItemEquippable.name = 'Equipment Base'
ItemEquippable.description = 'An item that can be equipped.'
ItemEquippable.category = t'item.category.equipment'
ItemEquippable.equip_slot = t'item.slot.accessory'
ItemEquippable.stackable = false

if CLIENT then
  function ItemEquippable:get_use_text()
    if self:is_equipped() then
      return t'item.option.unequip'
    else
      return t'item.option.equip'
    end
  end
end

function ItemEquippable:is_equipped()
  return self:get_data('equipped', false)
end

function ItemEquippable:on_equipped(player)
  local ply_inv = player:get_inventory()

  for slot, ids in ipairs(ply_inv) do
    for k, v in ipairs(ids) do
      local item_table = item.find_instance_by_id(v)

      if item_table.equip_slot and item_table.equip_slot == self.equip_slot and item_table:is_equipped() and item_table.instance_id != self.instance_id then
        return false
      end
    end
  end
end

function ItemEquippable:on_unequipped(player) end
function ItemEquippable:post_equipped(player) end
function ItemEquippable:post_unequipped(player) end

function ItemEquippable:equip(player, should_equip)
  if should_equip then
    if self:on_equipped(player) != false then
      self:set_data('equipped', true)
      self:post_equipped(player)
    end
  else
    if self:on_unequipped(player) != false then
      self:set_data('equipped', false)
      self:post_unequipped(player)
    end
  end
end

function ItemEquippable:on_use(player)
  if IsValid(self.entity) then
    self:do_menu_action('on_take', player)
  end

  self:equip(player, !self:is_equipped())

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
