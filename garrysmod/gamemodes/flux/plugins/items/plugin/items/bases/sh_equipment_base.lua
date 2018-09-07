if !ItemUsable then
  util.include("sh_usable_base.lua")
end

-- Alternatively, you can use item.CreateBase("ItemEquippable")
class 'ItemEquippable' extends 'ItemUsable'

ItemEquippable.name = "Equipment Base"
ItemEquippable.description = "An item that can be equipped."
ItemEquippable.category = t('item.category.equipment')
ItemEquippable.equip_slot = t('item.slot.accessory')
ItemEquippable.stackable = false

if CLIENT then
  function ItemEquippable:get_use_text()
    if self:IsEquipped() then
      return t('item.option.unequip')
    else
      return t('item.option.equip')
    end
  end
end

function ItemEquippable:IsEquipped()
  return self:get_data("equipped", false)
end

function ItemEquippable:OnEquipped(player)
  local playerInv = player:GetInventory()

  for slot, ids in ipairs(playerInv) do
    for k, v in ipairs(ids) do
      local itemTable = item.FindInstanceByID(v)

      if itemTable.equip_slot and itemTable.equip_slot == self.equip_slot and itemTable:IsEquipped() and itemTable.instance_id != self.instance_id then
        return false
      end
    end
  end
end

function ItemEquippable:OnUnEquipped(player) end
function ItemEquippable:PostEquipped(player) end
function ItemEquippable:PostUnEquipped(player) end

function ItemEquippable:Equip(player, bShouldEquip)
  if bShouldEquip then
    if self:OnEquipped(player) != false then
      self:set_data("equipped", true)
      self:PostEquipped(player)
    end
  else
    if self:OnUnEquipped(player) != false then
      self:set_data("equipped", false)
      self:PostUnEquipped(player)
    end
  end
end

function ItemEquippable:on_use(player)
  if IsValid(self.entity) then
    self:do_menu_action("on_take", player)
  end

  self:Equip(player, !self:IsEquipped())

  return true
end

function ItemEquippable:on_drop(player)
  if self:IsEquipped() then
    self:Equip(player, false)
  end
end

function ItemEquippable:on_loadout(player)
  if self:IsEquipped() then
    self:Equip(player, true)
  end
end

ItemEquippable = ItemEquippable
