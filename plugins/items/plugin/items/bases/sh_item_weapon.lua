if !ItemEquipable then
  require_relative 'sh_item_equipable'
end

class 'ItemWeapon' extends 'ItemEquipable'

ItemWeapon.name = 'Weapon Base'
ItemWeapon.description = 'A weapon that can be equipped.'
ItemWeapon.category = 'item.category.weapon'
ItemWeapon.equip_slot = 'item.slot.primary'
ItemWeapon.weapon_class = 'weapon_pistol'
ItemWeapon.background_color = Color(150, 100, 50)
ItemWeapon:add_button('unload', {
  name = 'item.option.unload',
  icon = 'icon16/add.png',
  callback = 'on_unload',
  on_show = function(item_obj)
    local ammo = item_obj:get_data('ammo', { 0, 0 })
    local weapon = PLAYER:GetWeapon(item_obj.weapon_class)

    if ((ammo[1] > 0 or ammo[2] > 0 or IsValid(weapon) and (weapon:Clip1() != 0 or weapon:Clip2() != 0))
    and !IsValid(item_obj.entity) and item_obj:is_equipped()) then
      return true
    end

    return false
  end
})

--- Called when the item gets equipped. Gives the player the weapon, selects it
-- and loads its clips with the ammo that is stored in the item's data.
-- @param owner [Player]
function ItemWeapon:post_equipped(owner)
  local weapon = owner:Give(self.weapon_class, true)

  if IsValid(weapon) then
    local ammo = self:get_data('ammo', { 0, 0 })

    owner:SelectWeapon(self.weapon_class)
    weapon:SetClip1(ammo[1])
    weapon:SetClip2(ammo[2])
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end

--- Called when the item gets unequipped. Strips the weapon from the player
-- and stores the contents of its clips in the item's data.
-- @param owner [Player]
function ItemWeapon:post_unequipped(owner)
  local weapon = owner:GetWeapon(self.weapon_class)

  if IsValid(weapon) then
    local ammo = { weapon:Clip1(), weapon:Clip2() }

    owner:StripWeapon(self.weapon_class)
    self:set_data('ammo', ammo)
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end

--- Called on the server when a player presses the unload button in the item's menu.
-- Empties the clips of the weapon and gives the ammo back to the player.
-- @param owner [Player]
function ItemWeapon:on_unload(owner)
  local weapon = owner:GetWeapon(self.weapon_class)
  local clip1, clip2 = weapon:Clip1(), weapon:Clip2()

  weapon:SetClip1(0)
  weapon:SetClip2(0)

  owner:GiveAmmo(clip1, weapon:GetPrimaryAmmoType())
  owner:GiveAmmo(clip2, weapon:GetSecondaryAmmoType())

  self:set_data('ammo', { 0, 0 })
end

--- Called on the server before the character of the player that has the item is saved.
-- Stores the contents of the weapon's clips in the item's data.
-- @param owner [Player]
function ItemWeapon:on_save(owner)
  local weapon = owner:GetWeapon(self.weapon_class)

  if IsValid(weapon) then
    local ammo = { weapon:Clip1(), weapon:Clip2() }

    self:set_data('ammo', ammo)
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end
