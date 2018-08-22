if (!CItemUsable) then
  util.Include("sh_usable_base.lua")
end

-- Alternatively, you can use item.CreateBase("CItemEquippable")
class "CItemEquippable" extends "CItemUsable"

CItemEquippable.Name = "Equipment Base"
CItemEquippable.Description = "An item that can be equipped."
CItemEquippable.Category = "#Item_Category_Equipment"
CItemEquippable.EquipSlot = "#Item_Slot_Accessory"
CItemEquippable.Stackable = false

if CLIENT then
  function CItemEquippable:GetUseText()
    if (self:IsEquipped()) then
      return "#Item_Option_Unequip"
    else
      return "#Item_Option_Equip"
    end
  end
end

function CItemEquippable:IsEquipped()
  return self:GetData("equipped", false)
end

function CItemEquippable:OnEquipped(player)
  local playerInv = player:GetInventory()

  for slot, ids in ipairs(playerInv) do
    for k, v in ipairs(ids) do
      local itemTable = item.FindInstanceByID(v)

      if (itemTable.EquipSlot and itemTable.EquipSlot == self.EquipSlot and itemTable:IsEquipped() and itemTable.instanceID != self.instanceID) then
        return false
      end
    end
  end
end

function CItemEquippable:OnUnEquipped(player) end
function CItemEquippable:PostEquipped(player) end
function CItemEquippable:PostUnEquipped(player) end

function CItemEquippable:Equip(player, bShouldEquip)
  if (bShouldEquip) then
    if (self:OnEquipped(player) != false) then
      self:SetData("equipped", true)
      self:PostEquipped(player)
    end
  else
    if (self:OnUnEquipped(player) != false) then
      self:SetData("equipped", false)
      self:PostUnEquipped(player)
    end
  end
end

function CItemEquippable:OnUse(player)
  if (IsValid(self.entity)) then
    self:DoMenuAction("OnTake", player)
  end

  self:Equip(player, !self:IsEquipped())

  return true
end

function CItemEquippable:OnDrop(player)
  if (self:IsEquipped()) then
    self:Equip(player, false)
  end
end

function CItemEquippable:OnLoadout(player)
  if (self:IsEquipped()) then
    self:Equip(player, true)
  end
end

ItemEquippable = CItemEquippable
