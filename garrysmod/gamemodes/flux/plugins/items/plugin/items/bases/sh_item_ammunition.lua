if !ItemUsable then
  require_relative 'sh_item_usable'
end

class 'ItemAmmo' extends 'ItemUsable'

ItemAmmo.name = 'Usable Items Base'
ItemAmmo.description = 'An item that can be used.'
ItemAmmo.category = 'item.category.ammo'
ItemAmmo.model = 'models/items/boxsrounds.mdl'
ItemAmmo.use_text = 'item.option.load'
ItemAmmo.ammo_class = 'Pistol'
ItemAmmo.ammo_count = 20

function ItemAmmo:on_use(player)
  player:GiveAmmo(self.ammo_count, self.ammo_class)
end
