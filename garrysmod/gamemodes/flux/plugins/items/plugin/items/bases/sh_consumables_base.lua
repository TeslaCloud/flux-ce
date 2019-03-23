if !ItemUsable then
  require_relative 'sh_usable_base'
end

class 'ItemConsumable' extends 'ItemUsable'

ItemConsumable.name = 'Consumables Base'
ItemConsumable.description = 'An item that can be consumed.'
ItemConsumable.category = t'item.category.consumables'

function ItemConsumable:on_use(player)
  if hook.run('PrePlayerConsumeItem', player, self) != false then
    hook.run('PlayerConsumeItem', player, self)
  end
end
