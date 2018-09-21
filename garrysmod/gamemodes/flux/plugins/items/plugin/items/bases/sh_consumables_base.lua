--[[
  Flux � 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

if !ItemUsable then
  util.include('sh_usable_base.lua')
end

-- Alternatively, you can use item.CreateBase('ItemConsumable')
class 'ItemConsumable' extends 'ItemUsable'

ItemConsumable.name = 'Consumables Base'
ItemConsumable.description = 'An item that can be consumed.'
ItemConsumable.category = t'item.category.consumables'

function ItemConsumable:on_use(player)
  if hook.run('PrePlayerConsumeItem', player, self) != false then
    hook.run('PlayerConsumeItem', player, self)
  end
end
