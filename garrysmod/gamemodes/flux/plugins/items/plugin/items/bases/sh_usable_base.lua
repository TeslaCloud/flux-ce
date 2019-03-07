-- Alternatively, you can use item.create_base('ItemUsable')
class 'ItemUsable' extends 'Item'

ItemUsable.name = 'Usable Items Base'
ItemUsable.description = 'An item that can be used.'
ItemUsable.action_sounds = {
  ['on_use'] = 'items/battery_pickup.wav'
}

-- Returns:
-- nothing/nil = removes item from the inventory as soon as it's used.
-- false = prevents item from being used at all.
-- true = prevents item from being removed upon use.
function Item:on_use(player) end
