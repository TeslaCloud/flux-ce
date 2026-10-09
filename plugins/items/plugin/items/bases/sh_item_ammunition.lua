--- ItemAmmo is the base class for boxes of ammunition.
-- A derived item sets `ammo_class`, the name of the ammo type as `Player:GiveAmmo` takes
-- it (`'Pistol'` by default), and `ammo_count`, the amount of ammo that one use gives
-- (16 by default). Using the item gives that ammo to the player. With `max_uses` above 1,
-- inherited from `ItemUsable`, a box can be used several times before it is gone.
-- With the `ammo_requires_weapon` config on, the ammo can only be loaded by a player who
-- carries a weapon that uses it.

if !ItemUsable then
  require_relative 'sh_item_usable'
end

class 'ItemAmmo' extends 'ItemUsable'

ItemAmmo.name = 'Ammunition Base'
ItemAmmo.description = 'An item that contains some ammo.'
ItemAmmo.category = 'item.category.ammo'
ItemAmmo.model = 'models/items/boxsrounds.mdl'
ItemAmmo.background_color = Color(200, 200, 70)
ItemAmmo.use_text = 'item.option.load'
ItemAmmo.ammo_class = 'Pistol'
ItemAmmo.ammo_count = 16
ItemAmmo.max_uses = 1

--- Checks whether the player carries a weapon that takes the ammo of the item as its
-- primary or secondary ammo. Only the weapons the player has on them count, so the weapon
-- items that are not equipped do not.
-- @param actor [Player]
-- @return [Boolean false also if the ammo type of the item does not exist]
function ItemAmmo:has_weapon_for(actor)
  local ammo_id = game.GetAmmoID(self.ammo_class)

  if !ammo_id or ammo_id < 0 then
    return false
  end

  for k, v in ipairs(actor:GetWeapons()) do
    if v:GetPrimaryAmmoType() == ammo_id or v:GetSecondaryAmmoType() == ammo_id then
      return true
    end
  end

  return false
end

--- Called by ItemUsable:on_use before the item is used. With the 'ammo_requires_weapon'
-- config on, refuses to load the ammo and notifies the player if they carry no weapon
-- that uses it.
-- @param actor [Player]
-- @return [Boolean false to prevent the use, nil otherwise]
function ItemAmmo:can_use(actor)
  if Config.get('ammo_requires_weapon') and !self:has_weapon_for(actor) then
    actor:notify('error.item.no_weapon_for_ammo')

    return false
  end
end

--- Called by ItemUsable:on_use when the item is used. Gives the player the ammo of the item.
-- @param actor [Player]
function ItemAmmo:use(actor)
  actor:GiveAmmo(self.ammo_count, self.ammo_class)
end
