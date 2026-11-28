--- Client hooks of the Pickup Objects plugin: keeps primary attack for the throw while the local
-- player holds something.

--- Leaves primary attack to the throw, and runs no hotbar action, while the local player carries
-- or drags an object.
-- @param client [Player the local player]
-- @param _item_obj [Item the item of the hotbar in their hands]
-- @return [Boolean false while they hold something, nil otherwise]
function PickupObjects:PlayerCanUseHotbarItem(client, _item_obj)
  if client:get_nv('pickup_holding') then
    return false
  end
end
