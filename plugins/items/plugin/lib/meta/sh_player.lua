--- Player extensions of the Items plugin: everything a player can do with their
-- inventories and the items in them.
-- A player has one inventory per type (`'main_inventory'`, `'hotbar'`, `'pockets'` and
-- so on), built by the `AdjustPlayerInventories` hook when their character becomes
-- active. The inventories belong to the character, and the items of the character are
-- loaded from the database into them right afterward. The functions that look items up
-- work on both the server and the client; those that take an optional `inv_type` go
-- through all inventories of the player when it is omitted and answer as for an empty
-- inventory when the player has no inventory of that type. The server-side functions that
-- give, take and move the items of a player are in `sv_player.lua`.
-- @module [Player]

local pairs = pairs
local table_add = table.Add
local player_meta = FindMetaTable('Player')

--- Get one of the player's inventories by type.
-- @param inv_type [String]
-- @return [Inventory, or nil if the player has no such inventory, as a player without a
--   character has none]
function player_meta:get_inventory(inv_type)
  return self:get_inventories()[inv_type]
end

--- Get all the player's inventories.
-- @return [Map inventories]
function player_meta:get_inventories()
  return self.inventories or {}
end

--- Get the items table from a certain inventory or from all of them.
-- Will return items from the specified inventory.
-- @variant player_meta:get_items(inv_type)
--   @param inv_type [String]
-- Will return items from all the inventories that the player has.
-- @variant player_meta:get_items()
-- @return [List<Item> items]
function player_meta:get_items(inv_type)
  if inv_type then
    return self:get_inventory(inv_type)?.:get_items() ?? {}
  else
    local items = {}

    for _, inventory in pairs(self:get_inventories()) do
      table_add(items, inventory:get_items())
    end

    return items
  end
end

--- Get only instance_ids from a certain inventory or from all of them.
-- Will return item ids only from the specified inventory.
-- @variant player_meta:get_items_ids(inv_type)
--   @param inv_type [String]
-- Will return item ids from all the inventories that the player has.
-- @variant player_meta:get_items_ids()
-- @return [List<Number> numbers]
function player_meta:get_items_ids(inv_type)
  if inv_type then
    return self:get_inventory(inv_type)?.:get_items_ids() ?? {}
  else
    local items = {}

    for _, inventory in pairs(self:get_inventories()) do
      table_add(items, inventory:get_items_ids())
    end

    return items
  end
end

--- Get instance_ids from a certain slot of the specified inventory.
-- @param x [Number]
-- @param y [Number]
-- @param inv_type [String]
-- @return [List<Number> numbers, or nil when the slot is out of bounds or the player has no
--   such inventory]
function player_meta:get_slot(x, y, inv_type)
  return self:get_inventory(inv_type)?.:get_slot(x, y)
end

--- Get the first instance_id from a certain slot of the specified inventory.
-- @param x [Number]
-- @param y [Number]
-- @param inv_type [String]
-- @return [Number instance id, or nil when the slot is empty or the player has no such
--   inventory]
function player_meta:get_first_in_slot(x, y, inv_type)
  return self:get_inventory(inv_type)?.:get_first_in_slot(x, y)
end

--- Get the amount of items with a certain id from the specified inventory or from all of them.
-- Will return the items count only from the specified inventory.
-- @variant player_meta:get_items_count(id, inv_type)
--   @param id [String]
--   @param inv_type [String]
-- Will return the items count from all the inventories that the player has.
-- @variant player_meta:get_items_count(id)
--   @param id [String]
-- @return [Number]
function player_meta:get_items_count(id, inv_type)
  if inv_type then
    return self:get_inventory(inv_type)?.:get_items_count(id) ?? 0
  else
    local count = 0

    for _, inventory in pairs(self:get_inventories()) do
      count += inventory:get_items_count(id)
    end

    return count
  end
end

--- Get the first item with a certain id from the specified inventory or from all of them.
-- Will return the item only from the specified inventory.
-- @variant player_meta:find_item(id, inv_type)
--   @param id [String]
--   @param inv_type [String]
-- Will return the item from all the inventories that the player has.
-- @variant player_meta:find_item(id)
--   @param id [String]
-- @return [Item]
function player_meta:find_item(id, inv_type)
  if inv_type then
    return self:get_inventory(inv_type)?.:find_item(id)
  else
    for _, inventory in pairs(self:get_inventories()) do
      local item_obj = inventory:find_item(id)

      if item_obj then
        return item_obj
      end
    end
  end
end

--- Get all items with a certain id from the specified inventory or from all of them.
-- Will return items only from the specified inventory.
-- @variant player_meta:find_items(id, inv_type)
--   @param id [String]
--   @param inv_type [String]
-- Will return items from all the inventories that the player has.
-- @variant player_meta:find_items(id)
--   @param id [String]
-- @return [List<Item> items]
function player_meta:find_items(id, inv_type)
  if inv_type then
    return self:get_inventory(inv_type)?.:find_items(id) ?? {}
  else
    local items = {}

    for _, inventory in pairs(self:get_inventories()) do
      table_add(items, inventory:find_items(id))
    end

    return items
  end
end

--- Checking if the player has a certain item by its id.
-- Will check only the specified inventory.
-- @variant player_meta:has_item(id, inv_type)
--   @param id [String]
--   @param inv_type [String]
-- Will check all the inventories that the player has.
-- @variant player_meta:has_item(id)
--   @param id [String]
-- @return [Boolean, Item found item]
function player_meta:has_item(id, inv_type)
  if inv_type then
    local inventory = self:get_inventory(inv_type)

    if !inventory then return false end

    return inventory:has_item(id)
  else
    for _, inventory in pairs(self:get_inventories()) do
      local found, item_obj = inventory:has_item(id)

      if found then
        return true, item_obj
      end
    end

    return false
  end
end

--- Checking if the player has a certain item by its instance id.
-- Will check only the specified inventory.
-- @variant player_meta:has_item_by_id(instance_id, inv_type)
--   @param instance_id [Number]
--   @param inv_type [String]
-- Will check all the inventories that the player has.
-- @variant player_meta:has_item_by_id(instance_id)
--   @param instance_id [Number]
-- @return [Boolean, Item found item]
function player_meta:has_item_by_id(instance_id, inv_type)
  if inv_type then
    local inventory = self:get_inventory(inv_type)

    if !inventory then return false end

    return inventory:has_item_by_id(instance_id)
  else
    for _, inventory in pairs(self:get_inventories()) do
      local found, item_obj = inventory:has_item_by_id(instance_id)

      if found then
        return true, item_obj
      end
    end

    return false
  end
end

--- Checks whether the player has an item with a certain id equipped, looking at every item
-- with that id in all of their inventories.
-- @param id [String]
-- @return [Boolean, Item the first equipped item]
function player_meta:has_item_equipped(id)
  local items = self:find_items(id)

  for i = 1, #items do
    local item_obj = items[i]

    if item_obj.is_equipped and item_obj:is_equipped() then
      return true, item_obj
    end
  end

  return false
end

--- Get the item object by the weapon class.
-- @param weapon_class [String]
-- @return [Item]
function player_meta:get_item_from_weapon(weapon_class)
  local items = self:get_items()

  for i = 1, #items do
    local item_obj = items[i]

    if item_obj.weapon_class == weapon_class and item_obj.is_equipped and item_obj:is_equipped() then
      return item_obj
    end
  end
end

--- Get the item of the weapon that the player is holding in their hands.
-- @return [Item]
function player_meta:get_active_weapon_item()
  local weapon = self:GetActiveWeapon()

  if IsValid(weapon) then
    return self:get_item_from_weapon(weapon:GetClass())
  end
end
