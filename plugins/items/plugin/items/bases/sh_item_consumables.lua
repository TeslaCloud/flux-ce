--- ItemConsumable is the base class for items that are consumed, such as food and drinks.
-- It has no effect of its own: using the item runs the `PrePlayerConsumeItem` and
-- `PlayerConsumeItem` hooks, where plugins and schemas apply the effect, and the item is
-- then removed. A derived item only has to set its appearance; `use_text` renames the use
-- option of its menu.

if !ItemUsable then
  require_relative 'sh_item_usable'
end

class 'ItemConsumable' extends 'ItemUsable'

ItemConsumable.name = 'Consumables Base'
ItemConsumable.description = 'An item that can be consumed.'
ItemConsumable.category = 'item.category.consumables'

--- Called on the server by the 'PlayerUseItem' hook when a player uses the item.
-- Runs the 'PlayerConsumeItem' hook unless 'PrePlayerConsumeItem' returns false.
-- Returns nothing, so the item is always removed afterward.
-- @param actor [Player]
function ItemConsumable:on_use(actor)
  --- Called on the server when a player uses a consumable item, before it is consumed.
  -- @param actor [Player The player using the item]
  -- @param item_obj [Item The consumable item]
  -- @return [Boolean Return false to keep `PlayerConsumeItem` from being run. The item is
  --   removed from the inventory either way]
  -- @realm [server]
  if hook.Run('PrePlayerConsumeItem', actor, self) != false then
    --- Called on the server when a player consumes a consumable item.
    -- This is the place to apply the effect of the item: the base class does nothing
    -- else with it. The item is removed from the inventory afterward.
    -- @param actor [Player The player consuming the item]
    -- @param item_obj [Item The consumable item]
    -- @realm [server]
    hook.Run('PlayerConsumeItem', actor, self)
  end
end
