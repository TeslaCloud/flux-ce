--- ItemAmmo is the base class for boxes of ammunition.
-- A derived item sets `ammo_class`, the name of the ammo type as `Player:GiveAmmo` takes
-- it (`'Pistol'` by default), and `ammo_count`, the amount of ammo that one use gives
-- (16 by default). Using the item gives that ammo to the player. With `max_uses` above 1,
-- inherited from `ItemUsable`, a box can be used several times before it is gone.

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

--- Called by ItemUsable:on_use when the item is used. Gives the player the ammo of the item.
-- @param actor [Player]
function ItemAmmo:use(actor)
  actor:GiveAmmo(self.ammo_count, self.ammo_class)
end
