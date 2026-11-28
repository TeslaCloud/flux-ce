--- Client side of the Inventories library: what an item dragged out of an inventory panel does
-- when it is dropped onto a background, such as the inventory tab, the tab menu or the
-- container view.
-- @module [Inventories]

mod 'Inventories'

--- Handles an item of an inventory dragged over a background or dropped onto it. Dropped onto
-- the thin air of the background (see `Hotbar.is_cursor_in_air`), the dragged items are dropped
-- into the world with the drop request of the inventory panels (`fl_item_drop`), as an entry of
-- the hotbar is on the same spot. Dropped onto a panel on the background that has no receiver
-- of its own, such as a button of the tab menu, a column of the equipment slots or the parts of
-- an inventory panel around its slots, the item stays and is shown in its inventory again (see
-- `Hotbar.receive_inventory_item`). While the item is dragged, only the hover highlight of the
-- inventory slot that was hovered last is taken off. It is the receiver of the tab menu for
-- items and the one that every `fl_inventory` panel gives its parent; the window of an opened
-- bag replaces it on itself with `Hotbar.receive_inventory_item`.
-- @param receiver [Panel the background: the parent of an fl_inventory panel or the tab menu]
-- @param dropped [List<Panel> the dragged fl_inventory_item panels]
-- @param is_dropped [Boolean]
function Inventories.receive_item_on_background(receiver, dropped, is_dropped)
  if is_dropped and Hotbar.is_cursor_in_air(receiver) then
    Cable.send('fl_item_drop', dropped[1].instance_ids)

    return
  end

  Hotbar.receive_inventory_item(receiver, dropped, is_dropped)
end
