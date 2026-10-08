--- ItemThrowable is the base class for weapons that are used up when thrown, such as
-- grenades.
-- A derived item sets `weapon_class`, the class of the weapon (`'weapon_frag'` by
-- default), and `thrown_ammo_class`, the ammo type that the weapon throws (`'Grenade'`
-- by default). Equipping the item gives the weapon with a single piece of that ammo and
-- makes it the active weapon. Unequipping strips the weapon and, if the ammo is gone,
-- takes the item away from the player. The Inventory plugin takes equipped throwable
-- items away when the `PlayerThrewGrenade` hook is run.
-- @module [ItemThrowable]

if !ItemWeapon then
  require_relative 'sh_item_weapon'
end

class 'ItemThrowable' extends 'ItemWeapon'

ItemThrowable.name = 'Throwable Base'
ItemThrowable.description = 'A throwable weapon.'
ItemThrowable.category = 'item.category.throwable'
ItemThrowable.equip_slot = 'item.slot.throwable'
ItemThrowable.weapon_class = 'weapon_frag'
ItemThrowable.thrown_ammo_class = 'Grenade'
ItemThrowable.background_color = Color(150, 150, 50)
ItemThrowable:add_button('item.option.unload', {
  icon = 'icon16/add.png',
  callback = 'on_unload',
  on_show = function(item_obj)
    return false
  end
})

--- Called when the item gets equipped.
-- Gives the player the throwable weapon with a single piece of ammo and makes it active.
-- @param owner [Player]
function ItemThrowable:post_equipped(owner)
  local weapon = owner:Give(self.weapon_class, true)

  if IsValid(weapon) then
    owner:SetActiveWeapon(weapon)
    owner:SetAmmo(1, self.thrown_ammo_class)
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end
end

--- Called when the item gets unequipped. Strips the weapon from the player
-- and takes the item away from them if they have no ammo for it left.
-- @param owner [Player]
function ItemThrowable:post_unequipped(owner)
  local weapon = owner:GetWeapon(self.weapon_class)

  if IsValid(weapon) then
    owner:StripWeapon(self.weapon_class)
  else
    Flux.dev_print('Invalid weapon class: '..self.weapon_class)
  end

  if owner:GetAmmoCount(self.thrown_ammo_class) == 0 then
    owner:take_item_by_id(self.instance_id)
  end
end
