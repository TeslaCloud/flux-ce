if !ItemWeapon then
  require_relative 'sh_item_weapon'
end

class 'ItemThrowable' extends 'ItemWeapon'

ItemThrowable.name = 'Throwable Base'
ItemThrowable.description = 'A throwable weapon.'
ItemThrowable.category = 'item.category.thrown'
ItemThrowable.equip_slot = 'item.slot.throwable'
ItemThrowable.weapon_class = 'weapon_frag'
ItemThrowable.thrown_ammo_class = 'Grenade'
ItemThrowable:add_button(t'item.option.unload', {
  icon = 'icon16/add.png',
  callback = 'on_unload',
  on_show = function(item_table)
    return false
  end
})

function ItemThrowable:post_equipped(player)
  local weapon = player:Give(self.weapon_class, true)

  if IsValid(weapon) then
    player:SetActiveWeapon(weapon)
    player:SetAmmo(1, self.thrown_ammo_class)
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end

function ItemThrowable:post_unequipped(player)
  local weapon = player:GetWeapon(self.weapon_class)

  if IsValid(weapon) then
    player:StripWeapon(self.weapon_class)

    if player:GetAmmoCount(self.thrown_ammo_class) == 0 then
      player:take_item_by_id(self.instance_id)
    end
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end
