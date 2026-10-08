--- Inventories are where players and other objects keep their items.
-- An `Inventory` is a grid of slots, `width` by `height`, with a numeric id and a type such
-- as `'main_inventory'` or `'hotbar'`. Every slot holds a stack of item instance ids. In
-- a multislot inventory an item covers as many slots as its `width` and `height` say and
-- can be rotated; in any other inventory every item takes a single slot. An inventory
-- can also grow with its contents (`infinite_width`, `infinite_height`) and be disabled.
--
-- When a character becomes active, the `CreatePlayerInventories` hook builds the
-- inventories of the player. This plugin creates the main inventory, the hotbar, the
-- pockets and the equipment slots there, sized by the `inventory_`, `hotbar_` and
-- `pockets_` config keys, and other plugins can add their own. Further inventories can be
-- created with `Inventory.new` for anything else that holds items, such as the bags based
-- on `ItemContainer`, and shown to a player with `Player:open_inventory`.
--
-- Inventories are managed by the server. Each one has a list of receivers: the players
-- who are sent its contents whenever `Inventory:sync` is called, and the only ones whose
-- requests to move or drop its items are accepted. A player is a receiver of their own
-- inventories and of those that were opened for them; once a second the server closes the
-- opened ones for the players who are no longer entitled to them, such as those who have
-- walked away from a container (`Inventory:can_be_viewed_by`). The client keeps a copy
-- and displays it in an `fl_inventory` panel made of `fl_inventory_item` slots. Dragging
-- an item to another slot asks the server to move it, which goes through the
-- `PlayerCanMoveItem`, `CanItemMove` or `CanItemTransfer`, `PreItemTransfer` and
-- `ItemTransferred` hooks; dragging it out of the panel drops it into the world. The
-- `fl_inventory_menu` panel is the inventory tab of the tab menu, and
-- `fl_inventory_container` shows another inventory next to the player's own.
--
-- The plugin also implements what the take, use and drop actions of the Items plugin do,
-- lets the slot binds select the items of the hotbar, and adds the GiveItem command and
-- an items tab to the spawn menu.
-- @module [Inventories]

PLUGIN:set_global('Inventories')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
require_relative 'sh_hooks'
