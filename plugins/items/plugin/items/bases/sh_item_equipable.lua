--- ItemEquipable is the base class for items that take effect while they are equipped,
-- such as weapons, radios and clothing. An item is equipped in one of two ways:
--
-- - an item that sets `equip_inv`, the type of an equipment inventory of the player such as
--   `'equipment_torso'`, is equipped for as long as it sits in that inventory: moving it in
--   equips it and moving it out unequips it, through the `can_transfer` and `on_transfer`
--   callbacks of the base class. An item cannot be equipped while another equipped item of
--   that inventory shares one of its `equip_slot` names. Clothing works this way (see
--   `ItemWearable`);
-- - an item without `equip_inv` is an item of the hotbar (`ItemEquipable:is_hotbar_item`):
--   it is equipped for as long as it is on the hotbar of the player whose main inventory or
--   pockets hold it, and the `equip_slot` names are compared with those of the other equipped
--   items of the hotbar (see `Hotbar`). Weapons, throwables and radios work this way.
--
-- `equip_slot` is a slot name or a list of slot names. Optionally, `disabled_inventories` lists
-- the types of inventories that are emptied into the main inventory and disabled while the
-- item is equipped.
--
-- A derived item overrides `post_equipped(owner)` and `post_unequipped(owner)` to apply
-- and remove its effect, and `can_equip(owner)` and `can_unequip(owner)` to forbid either.
-- The base class adds the equip button to the menu of the item. The `ItemEquipped` and
-- `ItemUnequipped` hooks tell other plugins about it. An item of the hotbar in the hands does
-- nothing on primary attack unless a derived item defines `on_hotbar_use(client)`, as the
-- radio does; a use action that it has stays in its menu.
-- @module [ItemEquipable]

class 'ItemEquipable' extends 'ItemBase'

ItemEquipable.name = 'Equipment Base'
ItemEquipable.description = 'An item that can be equipped.'
ItemEquipable.category = 'item.category.equipment'
ItemEquipable.stackable = false
ItemEquipable.equip_slot = 'item.slot.accessory'
ItemEquipable.disabled_inventories = {}

ItemEquipable:set_action_sound('on_equip', 'items/battery_pickup.wav')

ItemEquipable:add_button('equip', {
  get_name = item_obj -> item_obj:is_equipped() ? 'item.option.unequip' : 'item.option.equip',
  icon = 'icon16/user_suit.png',
  callback = 'on_equip'
})

--- Checks whether the item is equipped on the hotbar rather than in an equipment inventory,
-- which is the case for an item that sets no `equip_inv`.
-- @return [Boolean]
function ItemEquipable:is_hotbar_item()
  return self.equip_inv == nil
end

--- Checks whether the item is equipped: on the hotbar of the player whose storage holds it,
-- for an item of the hotbar, or in the inventory that it gets equipped in otherwise. The
-- client only knows the hotbar of the local player.
-- @return [Boolean]
-- @see [Hotbar.is_equipped]
function ItemEquipable:is_equipped()
  if self:is_hotbar_item() then
    return Hotbar.is_equipped(self)
  end

  return self.inventory_type == self.equip_inv
end

--- Checks whether two lists of slot names have a name in common; either can be a single name.
-- @param first [String/List<String>]
-- @param second [String/List<String>]
-- @return [Boolean false if either is nil]
local function names_overlap(first, second)
  if first == nil or second == nil then return false end

  if istable(first) then
    for _, name in pairs(first) do
      if names_overlap(name, second) then
        return true
      end
    end

    return false
  end

  if istable(second) then
    for _, name in pairs(second) do
      if name == first then
        return true
      end
    end

    return false
  end

  return first == second
end

--- Checks whether the item shares one of its equip_slot names with another item, which keeps
-- the two from being equipped together in the same inventory or on the same hotbar.
-- @param other [Item]
-- @return [Boolean]
function ItemEquipable:shares_equip_slot(other)
  return names_overlap(self.equip_slot, other.equip_slot)
end

--- Called on the server by the 'CanItemTransfer' hook before the item is moved to another
-- inventory or picked up into one. For an item of an equipment inventory, prevents equipping
-- the item if can_equip disallows it for the owner of that inventory or its equipment slot is
-- occupied, and prevents unequipping it if can_unequip disallows it; before the item is
-- equipped, the inventories of `disabled_inventories` are emptied, and the item is not
-- equipped if that fails. For an equipped item of the hotbar, prevents moving it out of the
-- storage of its player if can_unequip disallows it.
-- @param inventory [Inventory the inventory the item is being moved to]
-- @param _x [Number target slot, or nil if the position is yet to be found]
-- @param _y [Number target slot, or nil if the position is yet to be found]
-- @return [Boolean false to prevent the transfer, nil otherwise; String error phrase]
function ItemEquipable:can_transfer(inventory, _x, _y)
  if self:is_hotbar_item() then
    local owner = Hotbar.get_storage_owner(self)

    if owner and !Hotbar.is_storage(inventory, owner) and self:is_equipped() and self:can_unequip(owner) == false then
      return false, 'error.hotbar.cant_unequip'
    end

    return
  end

  local inv_type = inventory.type

  if inv_type == self.equip_inv then
    local owner = inventory.owner

    if self:can_equip(owner) == false then
      return false
    end

    for _, other in pairs(inventory:get_items()) do
      if other.equip_slot and other:is_equipped() and other.instance_id != self.instance_id
      and self:shares_equip_slot(other) then
        return false
      end
    end

    if IsValid(owner) and owner:IsPlayer() then
      local emptied, error_text = self:empty_disabled_inventories(owner)

      if !emptied then
        return false, error_text
      end
    end
  elseif self.inventory_type == self.equip_inv then
    if self:can_unequip(self:get_player()) == false then
      return false
    end
  end
end

--- Called on the server before the item is equipped: by ItemEquipable:can_transfer for an item
-- of an equipment inventory, and by `Hotbar.place` for an item of the hotbar.
-- Override it and return false to prevent the item from being equipped.
-- @param _owner [Player the player who is about to equip the item: the owner of the equipment
--   inventory it is being put into, or of the hotbar it is being put on]
-- @return [Boolean false to prevent equipping, nil otherwise]
function ItemEquipable:can_equip(_owner)
end

--- Called on the server before the item is unequipped: by ItemEquipable:can_transfer before
-- the item is moved out of its equipment inventory or, for an item of the hotbar, out of the
-- storage of its player, and by `Hotbar.clear` before it is taken off the hotbar. It is not
-- asked when the item is dropped, used up or taken away.
-- Override it and return false to prevent the item from being unequipped.
-- @param _owner [Player the player that has the item, or nil if no player has it]
-- @return [Boolean false to prevent unequipping, nil otherwise]
function ItemEquipable:can_unequip(_owner)
end

--- Called by ItemEquipable:equip when the item gets equipped.
-- Override it to apply the effects of the item to the player.
-- @param _owner [Player]
function ItemEquipable:post_equipped(_owner)
end

--- Called by ItemEquipable:equip when the item gets unequipped.
-- Override it to remove the effects of the item from the player.
-- @param _owner [Player]
function ItemEquipable:post_unequipped(_owner)
end

--- Moves the items of the inventories listed in disabled_inventories into the main
-- inventory of the player, all but this item itself.
-- @param owner [Player]
-- @return [Boolean false if an item could not be moved, String error phrase]
function ItemEquipable:empty_disabled_inventories(owner)
  for _, inventory_type in pairs(self.disabled_inventories) do
    local inventory = owner:get_inventory(inventory_type)

    if inventory then
      for _, instance_id in ipairs(inventory:get_items_ids()) do
        if instance_id != self.instance_id then
          local success, error_text = owner:transfer_item(instance_id, 'main_inventory')

          if success == false then
            return false, error_text
          end
        end
      end
    end
  end

  return true
end

--- Applies or reverts the equipped state of the item; it does not move the item itself.
-- Empties and disables (or enables back) the inventories listed in disabled_inventories, calls
-- post_equipped or post_unequipped and runs the 'ItemEquipped' or 'ItemUnequipped' hook.
-- The player is notified of an item that could not be moved out of an inventory that is
-- disabled; it stays there.
-- @param owner [Player]
-- @param should_equip [Boolean true to equip the item, false to unequip it]
function ItemEquipable:equip(owner, should_equip)
  if should_equip then
    local emptied, error_text = self:empty_disabled_inventories(owner)

    if !emptied then
      owner:notify(error_text)
    end

    for _, inventory_type in pairs(self.disabled_inventories) do
      local inventory = owner:get_inventory(inventory_type)

      if inventory then
        inventory:set_disabled(true)
      end
    end

    self:post_equipped(owner)

    --- Called when an equipable item has been equipped, after its `post_equipped` callback.
    -- This happens on the server when an item of an equipment inventory is about to enter
    -- that inventory (the transfer itself has not been made yet), when an item of the hotbar
    -- has been put on the hotbar, and every time the owner of an equipped item spawns.
    -- @param owner [Player The player who has the item]
    -- @param item_obj [Item The equipped item]
    -- @realm [server]
    hook.Run('ItemEquipped', owner, self)
  else
    for _, inventory_type in pairs(self.disabled_inventories) do
      local inventory = owner:get_inventory(inventory_type)

      if inventory then
        inventory:set_disabled(false)
      end
    end

    self:post_unequipped(owner)

    --- Called when an equipable item has been unequipped, after its `post_unequipped`
    -- callback. This happens on the server when an item of an equipment inventory is about to
    -- leave that inventory, and when an item of the hotbar has been taken off the hotbar,
    -- which happens as well when it leaves the storage of its player: it is moved elsewhere,
    -- dropped, taken away or removed after use.
    -- @param owner [Player The player who has the item]
    -- @param item_obj [Item The unequipped item]
    -- @realm [server]
    hook.Run('ItemUnequipped', owner, self)
  end
end

--- Called on the server by the 'PreTransferItem' hook when the item is about to change its
-- inventory. Equips or unequips an item of an equipment inventory if it enters or leaves that
-- inventory. Items of the hotbar are left to the hotbar, see `Hotbar.release_item`.
-- @param new_inventory [Inventory where the item goes, or nil if it is dropped]
-- @param old_inventory [Inventory where the item was, or nil if it is picked up]
function ItemEquipable:on_transfer(new_inventory, old_inventory)
  if self:is_hotbar_item() then return end

  if new_inventory and new_inventory.type == self.equip_inv then
    local owner = new_inventory.owner
    self:equip(owner, true)
  end

  if old_inventory and old_inventory.type == self.equip_inv then
    local owner = old_inventory.owner
    self:equip(owner, false)
  end
end

--- Called on the server when a player presses the equip button in the item's menu.
-- Puts an item of the hotbar on the first free item slot of the hotbar, or takes it off if it
-- is equipped already (see `Hotbar.toggle_equip`); the player is told why if that fails.
-- Moves any other item to its equipment inventory, or back to the main inventory if it is
-- equipped already. An item lying in the world is picked up and equipped.
-- @param owner [Player]
function ItemEquipable:on_equip(owner)
  if self:is_hotbar_item() then
    if IsValid(self.entity) then
      self:do_menu_action('on_take', owner)
    end

    if !Hotbar.is_in_storage(owner, self) then return end

    local changed, error_text, arguments = Hotbar.toggle_equip(owner, self)

    if !changed and error_text then
      owner:notify(error_text, arguments)
    end
  elseif IsValid(self.entity) then
    self:do_menu_action('on_take', owner, { inv_type = self.equip_inv })
  else
    if self:is_equipped() then
      owner:transfer_item(self.instance_id, 'main_inventory')
    else
      owner:transfer_item(self.instance_id, self.equip_inv)
    end
  end
end

if CLIENT then
  --- Called on the client when the local player clicks primary attack while the item is in
  -- their hands on the hotbar. An equipped item of the hotbar has no hotbar action unless a
  -- derived item defines one, so the click does nothing; a use action that the item has stays
  -- in its menu. Client-side only.
  -- @param _client [Player the local player]
  -- @see [ItemBase#on_hotbar_use]
  function ItemEquipable:on_hotbar_use(_client)
  end
end

--- Called on the server right after the player that has the item spawns, and once the items
-- of their character have been loaded if that takes longer. Applies the equipped state again
-- if the item is equipped.
-- @param owner [Player]
function ItemEquipable:on_loadout(owner)
  if self:is_equipped() then
    self:equip(owner, true)
  end
end
