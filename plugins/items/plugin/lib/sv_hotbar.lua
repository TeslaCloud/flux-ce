--- Server side of the Hotbar library: the checked functions that put items on the hotbar of a
-- player, move its entries and take them off, and the cleanup that keeps the entries in line
-- with what the player carries.
--
-- `Hotbar.place`, `Hotbar.move`, `Hotbar.clear`, `Hotbar.place_free`, `Hotbar.toggle_equip`
-- and `Hotbar.toggle_pin` apply the rules of the hotbar: the slot has to be one of the item
-- slots of the player, the item has to be in their storage and of a kind the hotbar takes,
-- `can_equip` and `can_unequip` of the item are asked and an item is not equipped while
-- another equipped item shares one of its `equip_slot` names. They return whether the hotbar
-- has changed and, when it has not, the phrase of the reason. They do not ask whether the
-- player is alive or how often they ask; the network handlers of the hotbar do that.
--
-- An item of the hotbar is equipped (`ItemEquipable:equip`) right after its entry has been put
-- on the hotbar, and unequipped right after its entry has been taken off. An equipped item that
-- leaves the storage of its player for any reason loses its entry (`Hotbar.release_item`);
-- a pinned entry stays. When the items of a character have been loaded, the entries whose item
-- is gone or outside of the storage, and those past the item slots, are dropped without
-- unequipping anything (`Hotbar.drop_invalid`), since the items have not been equipped yet in
-- this life; `on_loadout` equips the others.

local isnumber = isnumber
local isstring = isstring
local IsValid = IsValid

--- Returns a copy of the entries of the hotbar of a player, to be changed and stored.
-- @param owner [Player]
-- @return [Map]
local function copy_entries(owner)
  local copy = {}

  for slot, entry in pairs(Hotbar.get_entries(owner)) do
    copy[slot] = entry
  end

  return copy
end

--- Stores the entries of the hotbar of a player in the data of their active character, which
-- sends them to the player.
-- @param owner [Player]
-- @param entries [Map]
local function store(owner, entries)
  Characters.set_custom_data(owner:get_character(), Hotbar.data_key, next(entries) != nil ? entries : nil)
end

--- Takes the entry of a slot off the hotbar of a player, asking nothing, and unequips its
-- item if it is an equipped one.
-- @param owner [Player]
-- @param slot [Number]
local function release_slot(owner, slot)
  local entries = copy_entries(owner)
  local entry = entries[slot]

  if entry == nil then return end

  entries[slot] = nil

  store(owner, entries)

  local item_obj = isnumber(entry) and Item.find_instance_by_id(entry)

  if item_obj and isfunction(item_obj.equip) then
    item_obj:equip(owner, false)
  end
end

--- Puts an item on a slot of the hotbar of a player, asking nothing, and equips it if it is
-- an equipped one.
-- @param owner [Player]
-- @param slot [Number]
-- @param item_obj [Item]
-- @param kind [String 'equip' or 'pin']
local function put(owner, slot, item_obj, kind)
  local entries = copy_entries(owner)

  entries[slot] = Hotbar.get_entry(item_obj, kind)

  store(owner, entries)

  if kind == 'equip' then
    item_obj:equip(owner, true)
  end
end

--- Checks whether the entry of a slot of the hotbar of a player may be taken off: an equipped
-- item whose can_unequip callback refuses it may not.
-- @param owner [Player]
-- @param slot [Number]
-- @return [Boolean, String error phrase]
function Hotbar.can_clear(owner, slot)
  local entry = Hotbar.get_entries(owner)[slot]
  local item_obj = isnumber(entry) and Item.find_instance_by_id(entry)

  if item_obj and isfunction(item_obj.can_unequip) and item_obj:can_unequip(owner) == false then
    return false, 'error.hotbar.cant_unequip'
  end

  return true
end

--- Checks whether an item may be equipped on a slot of the hotbar of a player: its can_equip
-- callback has to allow it and no other equipped item of the hotbar may share one of its
-- equip_slot names, the entry of the slot itself aside. The inventories that the item
-- disables are emptied into the main inventory here; the item is refused if that fails.
-- @param owner [Player]
-- @param item_obj [Item an item of the hotbar, see `ItemEquipable:is_hotbar_item`]
-- @param slot [Number]
-- @return [Boolean, String error phrase, Map arguments of the phrase]
function Hotbar.can_equip(owner, item_obj, slot)
  if item_obj:can_equip(owner) == false then
    return false, 'error.inventory.cant_equip'
  end

  local conflict = Hotbar.find_conflict(owner, item_obj, slot)

  if conflict then
    return false, 'error.hotbar.equip_slot_taken', { item = conflict:get_name() }
  end

  return item_obj:empty_disabled_inventories(owner)
end

--- Puts an item of the storage of a player on a slot of their hotbar: equips an equipable item
-- of the hotbar there, or pins an item that can be used. An item that is on the hotbar already
-- is moved to the slot. An entry in the slot is taken off first, which unequips its item.
-- ```
-- local placed, error_text, arguments = Hotbar.place(actor, 1, item_obj)
--
-- if !placed and error_text then
--   actor:notify(error_text, arguments)
-- end
-- ```
-- @param owner [Player]
-- @param slot [Number one of the item slots of the player]
-- @param item_obj [Item]
-- @return [Boolean whether the hotbar has changed, String error phrase, Map arguments of the
--   phrase]
function Hotbar.place(owner, slot, item_obj)
  if !Hotbar.has_item_slots(owner) or !Hotbar.is_item_slot(slot) then return false end

  if !Item.is_instance(item_obj) or !Hotbar.is_in_storage(owner, item_obj) then
    return false, 'error.inventory.invalid_item'
  end

  local kind = Hotbar.get_kind(item_obj)

  if !kind then
    return false, 'error.hotbar.cant_place'
  end

  local current = Hotbar.find_slot(owner, Hotbar.get_entry(item_obj, kind))

  if current then
    return Hotbar.move(owner, current, slot)
  end

  if Hotbar.get_entries(owner)[slot] != nil then
    local can_clear, error_text = Hotbar.can_clear(owner, slot)

    if !can_clear then
      return false, error_text
    end
  end

  if kind == 'equip' then
    local can_equip, error_text, arguments = Hotbar.can_equip(owner, item_obj, slot)

    if !can_equip then
      return false, error_text, arguments
    end
  end

  release_slot(owner, slot)
  put(owner, slot, item_obj, kind)

  return true
end

--- Puts an item of the storage of a player on the first free item slot of their hotbar, see
-- `Hotbar.place`.
-- @param owner [Player]
-- @param item_obj [Item]
-- @return [Boolean whether the hotbar has changed, String error phrase, Map arguments of the
--   phrase]
function Hotbar.place_free(owner, item_obj)
  if !Hotbar.has_item_slots(owner) then return false end

  local entries = Hotbar.get_entries(owner)

  for slot = 1, Hotbar.get_slot_count() do
    if entries[slot] == nil then
      return Hotbar.place(owner, slot, item_obj)
    end
  end

  return false, 'error.hotbar.full'
end

--- Moves an entry of the hotbar of a player to another of their item slots, swapping it with
-- the entry there. Nothing is equipped or unequipped.
-- @param owner [Player]
-- @param from [Number the slot of the entry]
-- @param to [Number the slot to move it to]
-- @return [Boolean whether the hotbar has changed]
function Hotbar.move(owner, from, to)
  if !Hotbar.has_item_slots(owner) or !Hotbar.is_item_slot(from) or !Hotbar.is_item_slot(to) then return false end

  local entries = copy_entries(owner)

  if from == to or entries[from] == nil then return false end

  entries[from], entries[to] = entries[to], entries[from]

  store(owner, entries)

  return true
end

--- Takes the entry of one of the item slots of a player off their hotbar, which unequips an
-- equipped item, unless its can_unequip callback refuses.
-- @param owner [Player]
-- @param slot [Number]
-- @return [Boolean whether the hotbar has changed, String error phrase]
function Hotbar.clear(owner, slot)
  if !Hotbar.has_item_slots(owner) or !Hotbar.is_item_slot(slot) then return false end
  if Hotbar.get_entries(owner)[slot] == nil then return false end

  local can_clear, error_text = Hotbar.can_clear(owner, slot)

  if !can_clear then
    return false, error_text
  end

  release_slot(owner, slot)

  return true
end

--- Equips an equipable item of the hotbar on the first free item slot of its player, or
-- unequips it if it is equipped. This is what the equip button of its menu does.
-- @param owner [Player]
-- @param item_obj [Item an item of the hotbar in the storage of the player]
-- @return [Boolean whether the hotbar has changed, String error phrase, Map arguments of the
--   phrase]
function Hotbar.toggle_equip(owner, item_obj)
  local slot = Hotbar.find_slot(owner, item_obj.instance_id)

  if slot then
    return Hotbar.clear(owner, slot)
  end

  return Hotbar.place_free(owner, item_obj)
end

--- Pins a usable item on the first free item slot of its player, or unpins its item ID if it
-- is pinned. This is what the pin option of its menu does.
-- @param owner [Player]
-- @param item_obj [Item an item in the storage of the player]
-- @return [Boolean whether the hotbar has changed, String error phrase]
function Hotbar.toggle_pin(owner, item_obj)
  if !Item.is_instance(item_obj) or !Hotbar.can_pin(item_obj) then return false, 'error.hotbar.cant_place' end

  local slot = Hotbar.find_slot(owner, item_obj.id)

  if slot then
    return Hotbar.clear(owner, slot)
  end

  return Hotbar.place_free(owner, item_obj)
end

--- Takes an equipped item off the hotbar of a player and unequips it, asking nothing. The
-- Items plugin calls it when the item leaves the storage of the player, right before it is
-- moved, dropped or removed, or right after it has been taken away.
-- @param owner [Player]
-- @param item_obj [Item]
function Hotbar.release_item(owner, item_obj)
  if !IsValid(owner) or !owner:IsPlayer() or !owner:is_character_loaded() then return end

  local slot = Hotbar.find_slot(owner, item_obj.instance_id)

  if slot then
    release_slot(owner, slot)
  end
end

--- Checks whether an entry of a loaded hotbar may stay: the slot is one of the item slots, an
-- equipped item exists, is still an item of the hotbar and is in the storage of the player,
-- and a pinned item ID is that of an item that can still be pinned.
-- @param owner [Player]
-- @param slot [Any]
-- @param entry [Any]
-- @param slot_count [Number]
-- @return [Boolean]
local function is_valid_entry(owner, slot, entry, slot_count)
  if !isnumber(slot) or slot % 1 != 0 or slot < 1 or slot > slot_count then return false end

  if isnumber(entry) then
    local item_obj = Item.find_instance_by_id(entry)

    return item_obj != nil and Hotbar.get_kind(item_obj) == 'equip' and Hotbar.is_in_storage(owner, item_obj)
  end

  if isstring(entry) then
    local template = Item.find_by_id(entry)

    return template != nil and Hotbar.get_kind(template) == 'pin'
  end

  return false
end

--- @warning [Internal]
-- Drops the entries of the hotbar of a player that may not stay once the items of their
-- character have been loaded (see the file description), without unequipping anything.
-- @param owner [Player]
function Hotbar.drop_invalid(owner)
  local kept = {}
  local changed = false
  local slot_count = Hotbar.get_slot_count()

  for slot, entry in pairs(Hotbar.get_entries(owner)) do
    if is_valid_entry(owner, slot, entry, slot_count) then
      kept[slot] = entry
    else
      changed = true
    end
  end

  if changed then
    store(owner, kept)
  end
end

--- Takes the entries of the hotbar of a player that lie past their item slots off it, which
-- unequips their items. The Items plugin calls it for every player when the
-- `items_hotbar_slots` config is lowered.
-- @param owner [Player]
function Hotbar.trim(owner)
  if !Hotbar.has_item_slots(owner) or owner.loading_items then return end

  local slot_count = Hotbar.get_slot_count()

  for slot = slot_count + 1, Hotbar.max_slots do
    release_slot(owner, slot)
  end
end
