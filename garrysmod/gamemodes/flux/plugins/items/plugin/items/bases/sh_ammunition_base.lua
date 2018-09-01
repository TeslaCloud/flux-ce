if (!ItemUsable) then
  util.include("sh_usable_base.lua")
end

-- Alternatively, you can use item.CreateBase("ItemAmmo")
class 'ItemAmmo' extends 'ItemUsable'

ItemAmmo.name = "Usable Items Base"
ItemAmmo.description = "An item that can be used."
ItemAmmo.category = t('item.category.ammo')
ItemAmmo.model = "models/Items/BoxSRounds.mdl"
ItemAmmo.use_text = t('item.option.load')
ItemAmmo.ammo_class = "Pistol"
ItemAmmo.ammo_count = 20

function ItemAmmo:on_use(player)
  player:GiveAmmo(self.ammo_count, self.ammo_class)
end
