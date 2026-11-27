--- The Hotbar library: the row of numbered slots at the bottom of the screen that point at what
-- a player carries. The hotbar is not an inventory. An item on it stays where it is in the
-- storage of its player, the inventories whose types `Hotbar.storage_types` lists (the main
-- inventory and the pockets), and is shown in a slot besides.
--
-- Slots 1 to `items_hotbar_slots` (at most `Hotbar.max_slots`) belong to the player, and each
-- holds one of two kinds of entries:
--
-- - an equipable item without an equipment inventory (see `ItemEquipable:is_hotbar_item`),
--   such as a weapon, a radio or a flashlight, kept by its instance id. Being on the hotbar is
--   what equips such an item: `ItemEquipable:is_equipped` is read from here, the item is
--   equipped when it is put on a slot and unequipped when it is taken off or leaves the
--   storage of its player. It cannot be put on while another equipped item of the hotbar
--   shares one of its `equip_slot` names;
-- - an item that can be used and is not equipable, pinned by its item ID: the slot shows how
--   many of it the player carries and stays when they run out.
--
-- Slot 8 always holds the hands (`Hotbar.hands_weapon`), slot 9 the physgun for players with
-- the `physgun` permission and slot 0 the tool gun for players with the `toolgun`
-- permission; nothing can be put on them. A player without the inventories of a character,
-- such as a gamemaster in gamemaster mode, has these three slots only.
--
-- The entries of a character are kept in its generic character data under `Hotbar.data_key`,
-- a map of slot numbers to instance ids (Number) and item IDs (String), which is sent to the
-- owner of the character. The server changes them through the checked functions of
-- `sv_hotbar.lua`; the client selects a slot and shows the bar (`cl_hotbar.lua`) and turns the
-- keys and drags of the item interfaces into requests (`cl_hotbar_input.lua`).
-- @module [Hotbar]

local isnumber = isnumber
local istable = istable
local IsValid = IsValid

mod 'Hotbar'

--- Key of the generic character data that holds the entries of the hotbar.
Hotbar.data_key = 'hotbar'

--- The number of slots that a config can give to the items of a player.
Hotbar.max_slots = 7

--- The slot of the hands.
Hotbar.hands_slot = 8

--- The slot of the physgun.
Hotbar.physgun_slot = 9

--- The slot of the tool gun.
Hotbar.toolgun_slot = 0

--- The weapon of the hands: the first weapon of the default loadout.
Hotbar.hands_weapon = 'weapon_fists'

--- The weapon of the physgun slot.
Hotbar.physgun_weapon = 'weapon_physgun'

--- The weapon of the tool gun slot.
Hotbar.toolgun_weapon = 'gmod_tool'

--- The types of the inventories of a player whose items can be put on the hotbar. A plugin
-- that gives players another inventory for what they carry adds its type here.
Hotbar.storage_types = Hotbar.storage_types or { main_inventory = true, pockets = true }

Characters.network_data(Hotbar.data_key)

local no_entries = {}

--- Returns the entries of the hotbar of the active character of a player. The client only
-- knows them for the local player. The table must not be changed: the server replaces it as
-- a whole whenever an entry changes.
-- @param owner [Player]
-- @return [Map slot numbers to instance ids (Number) of equipped items and item IDs (String)
--   of pinned ones; an empty table when there are none]
function Hotbar.get_entries(owner)
  local entries = owner:get_character_data(Hotbar.data_key)

  return istable(entries) and entries or no_entries
end

--- Returns how many slots players have for their items: the `items_hotbar_slots` config,
-- from 1 to `Hotbar.max_slots`.
-- @return [Number]
function Hotbar.get_slot_count()
  local count = tonumber(Config.get('items_hotbar_slots')) or Hotbar.max_slots

  return math.Clamp(math.floor(count), 1, Hotbar.max_slots)
end

--- Checks whether a value is one of the slots that players have for their items now.
-- @param slot [Any]
-- @return [Boolean]
function Hotbar.is_item_slot(slot)
  return isnumber(slot) and slot % 1 == 0 and slot >= 1 and slot <= Hotbar.get_slot_count()
end

--- Checks whether a player has slots for items on their hotbar: a player with a loaded
-- character and its inventories.
-- @param owner [Player]
-- @return [Boolean]
function Hotbar.has_item_slots(owner)
  return IsValid(owner) and owner:IsPlayer() and owner.inventories != nil and owner:is_character_loaded() == true
end

--- Finds the slot of the hotbar of a player that holds an entry.
-- @param owner [Player]
-- @param entry [Number/String instance id of an equipped item or item ID of a pinned one]
-- @return [Number the slot, nil if the entry is not on the hotbar]
function Hotbar.find_slot(owner, entry)
  local entries = Hotbar.get_entries(owner)

  for slot = 1, Hotbar.max_slots do
    if entries[slot] == entry then
      return slot
    end
  end
end

--- Checks whether an inventory is part of the storage of a player, whose items can be put on
-- the hotbar of that player.
-- @param inventory [Inventory nil is never part of it]
-- @param owner [Player]
-- @return [Boolean]
function Hotbar.is_storage(inventory, owner)
  return inventory != nil and owner != nil and inventory.owner == owner and Hotbar.storage_types[inventory.type] == true
end

--- Returns the player whose storage holds an item, without looking inside of container items.
-- @param item_obj [Item]
-- @return [Player, nil if the item is not in the storage of a player]
function Hotbar.get_storage_owner(item_obj)
  local inventory = Inventories.find(item_obj.inventory_id)
  local owner = inventory and inventory.owner

  if IsValid(owner) and owner:IsPlayer() and Hotbar.storage_types[inventory.type] then
    return owner
  end
end

--- Checks whether an item is in one of the slots of the storage of a player.
-- @param owner [Player]
-- @param item_obj [Item]
-- @return [Boolean]
function Hotbar.is_in_storage(owner, item_obj)
  local inventory = Inventories.find(item_obj.inventory_id)

  return Hotbar.is_storage(inventory, owner) and inventory:has_item_by_id(item_obj.instance_id) == true
end

--- Checks whether an item is equipped on the hotbar of the player whose storage holds it.
-- This is what `ItemEquipable:is_equipped` answers for the items of the hotbar.
-- @param item_obj [Item]
-- @return [Boolean]
function Hotbar.is_equipped(item_obj)
  local owner = Hotbar.get_storage_owner(item_obj)

  return owner != nil and Hotbar.find_slot(owner, item_obj.instance_id) != nil
end

--- Checks whether an item can be pinned to the hotbar: an item that has a use action and is
-- not equipable.
-- @param item_obj [Item an item instance or template]
-- @return [Boolean]
function Hotbar.can_pin(item_obj)
  return item_obj.on_use != nil and !item_obj:is('equipable')
end

--- Tells what an item would be on the hotbar.
-- @param item_obj [Item an item instance or template]
-- @return [String 'equip' for an item that is equipped by being on the hotbar, 'pin' for one
--   that is pinned to it; nil for an item that cannot be put on it]
function Hotbar.get_kind(item_obj)
  if isfunction(item_obj.is_hotbar_item) then
    return item_obj:is_hotbar_item() ? 'equip' : nil
  end

  if Hotbar.can_pin(item_obj) then
    return 'pin'
  end
end

--- Returns the entry that an item is kept as on the hotbar.
-- @param item_obj [Item]
-- @param kind [String 'equip' or 'pin', see `Hotbar.get_kind`]
-- @return [Number the instance id of an equipped item, String the item ID of a pinned one]
function Hotbar.get_entry(item_obj, kind)
  return kind == 'equip' ? item_obj.instance_id : item_obj.id
end

--- Finds the equipped item of the hotbar of a player that shares an equip_slot name with
-- another item, which keeps that item from being equipped on the hotbar.
-- @param owner [Player]
-- @param item_obj [Item the item to equip]
-- @param ignored_slot=nil [Number a slot whose entry does not count, such as the one the item
--   is about to replace]
-- @return [Item the equipped item, nil if there is none]
function Hotbar.find_conflict(owner, item_obj, ignored_slot)
  local entries = Hotbar.get_entries(owner)

  for slot = 1, Hotbar.max_slots do
    local entry = entries[slot]

    if slot != ignored_slot and isnumber(entry) and entry != item_obj.instance_id then
      local other = Item.find_instance_by_id(entry)

      if other and item_obj:shares_equip_slot(other) then
        return other
      end
    end
  end
end

--- Returns the equipped items of the hotbar of a player that are in their storage, in the
-- order of their slots.
-- @param owner [Player]
-- @return [List<Item>]
function Hotbar.get_equipped(owner)
  local items = {}
  local entries = Hotbar.get_entries(owner)

  for slot = 1, Hotbar.max_slots do
    local entry = entries[slot]
    local item_obj = isnumber(entry) and Item.find_instance_by_id(entry)

    if item_obj and Hotbar.is_storage(Inventories.find(item_obj.inventory_id), owner) then
      items[#items + 1] = item_obj
    end
  end

  return items
end

--- Counts the items with an item ID in the storage of a player, the way a pinned slot shows
-- them, and finds the first of them. Container items are not looked into.
-- @param owner [Player]
-- @param item_id [String]
-- @return [Number how many there are, Item the first of them; nil when there is none]
function Hotbar.count_items(owner, item_id)
  local count, first = 0, nil
  local find_instance_by_id = Item.find_instance_by_id

  for inv_type in pairs(Hotbar.storage_types) do
    local inventory = owner:get_inventory(inv_type)
    local slots = inventory and inventory.slots

    if slots then
      for y = 1, inventory.height do
        local row = slots[y]

        for x = 1, inventory.width do
          local stack = row and row[x]

          if istable(stack) then
            for i = 1, #stack do
              local item_obj = find_instance_by_id(stack[i])

              if item_obj and item_obj.id == item_id and item_obj.x == x and item_obj.y == y then
                count += 1
                first = first or item_obj
              end
            end
          end
        end
      end
    end
  end

  return count, first
end

--- Fills a list with the slots of the hotbar that a player is shown, in the order of the bar:
-- their item slots, the hands, then the physgun and the tool gun if they are allowed them.
-- The list is reused: what it holds past the slots is removed.
-- @param layout [List<Number> the list to fill]
-- @param slot_count [Number how many item slots the player has, 0 for none]
-- @param physgun [Boolean whether the player is shown the physgun slot]
-- @param toolgun [Boolean whether the player is shown the tool gun slot]
-- @return [Number how many slots the list holds]
function Hotbar.build_layout(layout, slot_count, physgun, toolgun)
  local count = 0

  for slot = 1, slot_count do
    count += 1
    layout[count] = slot
  end

  count += 1
  layout[count] = Hotbar.hands_slot

  if physgun then
    count += 1
    layout[count] = Hotbar.physgun_slot
  end

  if toolgun then
    count += 1
    layout[count] = Hotbar.toolgun_slot
  end

  for i = #layout, count + 1, -1 do
    layout[i] = nil
  end

  return count
end

--- Finds the position of a slot in a layout of the bar.
-- @param layout [List<Number> slots in the order of the bar, see `Hotbar.build_layout`]
-- @param count [Number how many slots the layout holds]
-- @param slot [Number/Nil the slot, nil for none, which has no position]
-- @return [Number the position, nil if the slot is nil or not in the layout]
function Hotbar.find_position(layout, count, slot)
  for i = 1, count do
    if layout[i] == slot then
      return i
    end
  end
end

--- Returns the slot that comes a step away from another in a layout of the bar, wrapping
-- around at either end. From nil or a slot that is not in the layout, a step forward goes to
-- the first slot and a step back to the last one.
-- @param layout [List<Number> slots in the order of the bar, see `Hotbar.build_layout`]
-- @param count [Number how many slots the layout holds]
-- @param slot [Number/Nil the slot to start from, nil for none]
-- @param step [Number 1 for the next slot, -1 for the previous one]
-- @return [Number]
function Hotbar.step_slot(layout, count, slot, step)
  local position = Hotbar.find_position(layout, count, slot)

  if !position then
    return layout[step > 0 ? 1 : count]
  end

  return layout[(position - 1 + step) % count + 1]
end

--- Works out which slot is selected once the weapon in the hands of a player has changed.
-- The selected slot stays when it puts that weapon in the hands, and when it is a weapon slot
-- whose weapon the player has lost, which is how the hands go up when the selected weapon is
-- unequipped. Otherwise the hands select slot 8, and any other weapon the first slot of the
-- layout that puts it in the hands. A weapon that no slot puts in the hands leaves the
-- selection as it is, or selects the hands if the selected slot is not in the layout.
-- @param layout [List<Number> slots in the order of the bar, see `Hotbar.build_layout`]
-- @param count [Number how many slots the layout holds]
-- @param selected [Number the selected slot]
-- @param classes [Map slot numbers to the class of the weapon that each slot of the layout
--   puts in the hands]
-- @param active_class [String the class of the weapon in the hands]
-- @param selected_owned [Boolean whether the player has the weapon of the selected slot]
-- @return [Number the slot to select]
function Hotbar.follow_weapon(layout, count, selected, classes, active_class, selected_owned)
  local displayed = Hotbar.find_position(layout, count, selected) != nil

  if displayed and classes[selected] == active_class then
    return selected
  end

  if active_class == Hotbar.hands_weapon then
    if displayed and !selected_owned then
      return selected
    end

    return Hotbar.hands_slot
  end

  for i = 1, count do
    local slot = layout[i]

    if classes[slot] == active_class then
      return slot
    end
  end

  return displayed ? selected : Hotbar.hands_slot
end
