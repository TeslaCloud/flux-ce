if !ItemEquippable then
  util.include('sh_equipment_base.lua')
end

-- Alternatively, you can use item.CreateBase('ItemWeapon')
class 'ItemWeapon' extends 'ItemEquippable'

ItemWeapon.name = 'Weapon Base'
ItemWeapon.description = 'An weapon that can be equipped.'
ItemWeapon.category = t'item.category.weapon'
ItemWeapon.equip_slot = t'weapon.category.secondary'
ItemWeapon.weapon_class = 'weapon_pistol'
ItemWeapon:add_button(t'item.option.unload', {
  icon = 'icon16/add.png',
  callback = 'OnUnload',
  on_show = function(item_table)
    local ammo = item_table:get_data('ammo', {0, 0})
    local weapon = fl.client:GetWeapon(item_table.weapon_class)

    if ((ammo[1] > 0 or ammo[2] > 0 or IsValid(weapon) and (weapon:Clip1() != 0 or weapon:Clip2() != 0))
      and !IsValid(item_table.Entity) and item_table:IsEquipped()) then
      return true
    end
  end
})

function ItemWeapon:PostEquipped(player)
  local weapon = player:Give(self.weapon_class, true)

  if IsValid(weapon) then
    local ammo = self:get_data('ammo', {0, 0})

    player:SetActiveWeapon(weapon)
    weapon:SetClip1(ammo[1])
    weapon:SetClip2(ammo[2])
  else
    fl.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end

function ItemWeapon:PostUnEquipped(player)
  local weapon = player:GetWeapon(self.weapon_class)

  if IsValid(weapon) then
    local ammo = {weapon:Clip1(), weapon:Clip2()}

    player:StripWeapon(self.weapon_class)
    self:set_data('ammo', ammo)
  else
    fl.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end

function ItemWeapon:OnUnload(player)
  local weapon = player:GetWeapon(self.weapon_class)
  local clip1, clip2 = weapon:Clip1(), weapon:Clip2()

  weapon:SetClip1(0)
  weapon:SetClip2(0)
  player:GiveAmmo(clip1, weapon:GetPrimaryAmmoType())
  player:GiveAmmo(clip2, weapon:GetSecondaryAmmoType())
  self:set_data('ammo', {0, 0})
end

function ItemWeapon:on_save(player)
  local weapon = player:GetWeapon(self.weapon_class)

  if IsValid(weapon) then
    local ammo = {weapon:Clip1(), weapon:Clip2()}

    self:set_data('ammo', ammo)
  else
    fl.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end
