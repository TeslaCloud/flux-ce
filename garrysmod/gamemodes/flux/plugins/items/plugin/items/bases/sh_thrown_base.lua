if !ItemWeapon then
  util.include('sh_weapon_base.lua')
end

-- Alternatively, you can use item.create_base('ItemThrown')
class 'ItemThrown' extends 'ItemWeapon'

ItemThrown.name = 'Thrown Base'
ItemThrown.description = 'An weapon that can be thrown.'
ItemThrown.category = t'item.category.thrown'
ItemThrown.equip_slot = 'item.slot.throwable'
ItemThrown.weapon_class = 'weapon_frag'
ItemThrown.thrown_ammo_class = 'Grenade'
ItemThrown:add_button(t'item.option.unload', {
  icon = 'icon16/add.png',
  callback = 'on_unload',
  on_show = function(item_table)
    return false
  end
})

function ItemThrown:post_equipped(player)
  local weapon = player:Give(self.weapon_class, true)

  if IsValid(weapon) then
    player:SetActiveWeapon(weapon)
    player:SetAmmo(1, self.thrown_ammo_class)
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end

function ItemThrown:post_unequipped(player)
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
