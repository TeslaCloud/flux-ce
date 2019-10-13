if !ItemUsable then
  require_relative 'sh_item_usable'
end

class 'ItemAmmo' extends 'ItemUsable'

ItemAmmo.name = 'Ammunition Base'
ItemAmmo.description = 'An item that contains some ammo.'
ItemAmmo.category = 'item.category.ammo'
ItemAmmo.model = 'models/items/boxsrounds.mdl'
ItemAmmo.use_text = 'item.option.load'
ItemAmmo.ammo_class = 'Pistol'
ItemAmmo.ammo_count = 16
ItemAmmo.max_uses = 1

function ItemAmmo:use(player)
  player:GiveAmmo(self.ammo_count, self.ammo_class)
end
