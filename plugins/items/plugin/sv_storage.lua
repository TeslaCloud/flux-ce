--- Database storage of the item instances.
-- Every instance is a row of the `items` table, keyed by its instance id. A row holds the
-- id of the item template (`template_id`), the custom data and the overridden fields of
-- the instance, serialized (`data`, `overrides`), and where the instance is. That is one
-- of these:
--
-- - in an inventory of a character: `character_id`, with the type of the inventory and the
--   slot (`inventory_type`, `x`, `y`, `rotated`);
-- - inside of a container item such as a bag: `parent_id`, the instance id of the
--   container item, with the slot;
-- - inside of a container prop of a map: `container_id`, which the prop keeps in its own
--   `container_id` field, and `map`, with the slot;
-- - lying in the world: `map`, the position (`pos_x`, `pos_y`, `pos_z`), the angles
--   (`pitch`, `yaw`, `roll`) and who dropped it (`dropped_by_character_id`,
--   `dropped_by_steam_id`).
--
-- Rows refer to where an item is directly: the contents of a bag point to the bag, not to
-- the character carrying it. When a character is deleted, its items are deleted with it,
-- and so are the contents of a container item that is deleted. Foreign keys take care of
-- that where the database enforces them, and `Item.delete_character_items` and
-- `Item.remove` do it on every database.
--
-- Only the custom data that differs from the default data of the template is saved. A
-- default key that an instance has removed is saved as removed. The serialized custom data
-- and the serialized overridden fields of an instance must each stay below 64 KB, the size
-- of a MySQL text column; an instance with more is not written, and an error is printed.
--
-- The server keeps only the instances that are in use. The Inventory plugin loads the
-- items of a character with `Item.load_character` when the character becomes active and
-- unloads them with `Item.unload` once it is not in use anymore, so they follow the
-- character from map to map. `Item.load_map` loads the items of the current map when it
-- starts: the items lying in the world are spawned, and the `OnMapItemsLoaded` hook hands
-- all of them to the plugins that put them where they belong.
--
-- On the server an instance carries where it is in its `character_id`, `parent_id` and
-- `container_id` fields, which the inventory that holds it sets through
-- `Item.set_holder`, or in its entity when it lies in the world. Whatever changes an
-- instance marks it with `Item.mark_dirty`. `Item.save` writes the marked instances whose
-- row has changed since it was last written, every few seconds, after the framework has
-- saved its data, when a character is saved and when items are unloaded. The new and
-- changed rows and the deleted ones of a save are written in one transaction. A row
-- counts as written once the transaction has been committed; if it fails, the instance
-- is marked again and written with the next save, on its own if its own statement failed.
-- Unloaded instances stay in memory until they have been written. When the server shuts
-- down or changes the map, the last save waits until the database has run every query.
--
-- When changes are written, an instance that is held by nothing and lies nowhere is
-- removed. An instance in an inventory without a holder is not written at all, so its
-- row keeps the place it was last saved in.
--
-- Instance ids are handed out by the server right away, without waiting for the database.
-- They come from blocks of ids that the server reserves by inserting a row into the
-- `item_id_blocks` table: block number n holds the ids from n * 1000 to n * 1000 + 999.
-- The database numbers every inserted row, so no block is reserved twice. The ids that a
-- server has not used when it stops are skipped. Rows of `item_id_blocks` must never be
-- deleted, since some databases hand out the number of a deleted last row again. A block
-- is reserved when the database connects, and the next one in the background while the
-- current one is half used up. Container props get their `container_id` from the same ids.

local pairs = pairs
local ipairs = ipairs
local istable = istable
local tonumber = tonumber

local block_size = 1000
local save_interval = 5
local chunk_size = 200
local max_serialized_length = 65535
local max_retries = 3
local removed_marker = { removed_default = true }

local columns = {
  'template_id', 'character_id', 'parent_id', 'container_id', 'map',
  'inventory_type', 'x', 'y', 'rotated',
  'pos_x', 'pos_y', 'pos_z', 'pitch', 'yaw', 'roll',
  'dropped_by_character_id', 'dropped_by_steam_id',
  'data', 'overrides'
}

local instances = Item.instances

Item.id_blocks = Item.id_blocks or {}
Item.dirty = Item.dirty or {}
Item.deleted = Item.deleted or {}

local id_blocks = Item.id_blocks
local dirty = Item.dirty
local deleted = Item.deleted
local reserving = false
local writes_pending = 0

--- Runs a function with the database adapter in sync mode, so that the queries started in
-- it are done when it returns. The adapter waits for the queries started before as well.
-- @param callback [Function]
-- @return [Any what the function returns]
local function with_sync(callback)
  local adapter = ActiveRecord.adapter
  local was_sync = adapter:is_sync()

  adapter:sync(true)

  local success, result = pcall(callback)

  adapter:sync(was_sync)

  if !success then
    error_with_traceback(tostring(result))

    return
  end

  return result
end

--- Checks whether the database is ready to load and save items. Server-side only.
-- @return [Boolean]
function Item.is_storage_ready()
  return ActiveRecord.ready == true and ActiveRecord.adapter != nil
end

local storage_ready = Item.is_storage_ready

--- Converts a database value to a boolean. Databases return booleans as booleans, numbers
-- or strings, depending on the database and its module.
-- @param value [Any]
-- @return [Boolean]
local function to_bool(value)
  return value == true or value == 1 or value == '1' or value == 't' or value == 'true'
end

--- Checks whether two values are equal, comparing tables by their contents.
-- @param a [Any]
-- @param b [Any]
-- @return [Boolean]
local function deep_equal(a, b)
  if a == b then return true end
  if !istable(a) or !istable(b) then return false end

  for key, value in pairs(a) do
    if !deep_equal(value, b[key]) then return false end
  end

  for key in pairs(b) do
    if a[key] == nil then return false end
  end

  return true
end

--- Serializes a table for a text column.
-- @param tab [Map]
-- @return [String the serialized table, or nil if there is nothing in it]
local function encode(tab)
  if !istable(tab) or next(tab) == nil then return end

  local serialized = table.serialize(tab)

  if serialized != '' then
    return serialized
  end
end

--- Turns the value of a serialized column back into a table.
-- @param value [Any]
-- @return [Map the table, or nil if there is nothing to decode]
local function decode(value)
  if !isstring(value) or value == '' then return end

  local decoded = table.deserialize(value)

  if istable(decoded) then
    return decoded
  end
end

--- Returns the template of an instance.
-- @param item_obj [Item]
-- @return [Item]
local function get_template(item_obj)
  local meta = getmetatable(item_obj)

  return meta and istable(meta.__index) and meta.__index or item_obj
end

--- Returns the custom data of an instance that is saved: the keys whose value differs from
-- the default data of the template, and a marker for every default key that is gone.
-- @param item_obj [Item]
-- @return [Map]
local function own_data(item_obj)
  local data = istable(item_obj.data) and item_obj.data or {}
  local defaults = get_template(item_obj).data

  defaults = istable(defaults) and defaults or {}

  local own = {}

  for key, value in pairs(data) do
    if !deep_equal(value, defaults[key]) then
      own[key] = value
    end
  end

  for key in pairs(defaults) do
    if data[key] == nil then
      own[key] = removed_marker
    end
  end

  return own
end

--- Splits saved custom data into the values to set and the default keys to remove.
-- @param data [Map/nil]
-- @return [Map values, Map removed keys]
local function split_data(data)
  local removed = {}

  if !istable(data) then return nil, removed end

  for key, value in pairs(data) do
    if deep_equal(value, removed_marker) then
      removed[key] = true
      data[key] = nil
    end
  end

  return data, removed
end

--- Rounds a coordinate to a tenth, so that an item which barely moves is not saved again.
-- @param value [Number]
-- @return [Number]
local function round(value)
  return math.Round(value, 1)
end

--- Builds a string out of the rounded position and angles of an entity.
-- @param entity [Entity]
-- @return [String]
local function place_of(entity)
  local pos, ang = entity:GetPos(), entity:GetAngles()

  return string.format('%.1f %.1f %.1f %.1f %.1f %.1f', pos.x, pos.y, pos.z, ang.p, ang.y, ang.r)
end

--- Reserves a block of instance ids by inserting a row into the item_id_blocks table.
-- @param callback=nil [Function called once the query has finished, whether it worked]
local function reserve_block(callback)
  local function done()
    if callback then
      callback()
    end
  end

  local now = to_datetime(os.time())
  local query = ActiveRecord.Database:insert('item_id_blocks')
    query:insert('created_at', now)
    query:insert('updated_at', now)
    query:callback(function(result, query_str, time, bindings)
      print_query('Item ID Block Create ('..time..'s)', query_str, bindings)

      local block = istable(result) and istable(result[1]) and tonumber(result[1].id)

      if block then
        local first = block * block_size

        id_blocks[#id_blocks + 1] = { next = first, last = first + block_size - 1 }
      end

      done()
    end)

    query:on_error(done)
  query:execute()
end

--- Counts the instance ids that are reserved and not handed out yet.
-- @return [Number]
local function ids_left()
  local count = 0

  for _, block in ipairs(id_blocks) do
    count = count + block.last - block.next + 1
  end

  return count
end

--- Reserves the first block of instance ids, unless there is one already. Called when the
-- database is ready, while the adapter is in sync mode.
function Item.reserve_ids()
  if ids_left() > 0 then return end

  with_sync(reserve_block)
end

--- Hands out a new item instance id. No id is ever handed out twice, and a restart does
-- not change that. Waits for the database only when the reserved ids have run out.
-- Server-side only.
-- @return [Number the new instance id, or nil if the database is not ready]
function Item.generate_id()
  if ids_left() == 0 then
    if !storage_ready() then
      error_with_traceback('Cannot create an item instance before the database is ready!')

      return
    end

    with_sync(reserve_block)
  end

  local block = id_blocks[1]

  if !block then
    error_with_traceback('Failed to reserve item instance ids!')

    return
  end

  local instance_id = block.next

  block.next = instance_id + 1

  if block.next > block.last then
    table.remove(id_blocks, 1)
  end

  if !reserving and ids_left() < block_size * 0.5 then
    reserving = true

    reserve_block(function()
      reserving = false
    end)
  end

  return instance_id
end

--- Makes an inventory the holder of an instance: the instance is saved as being in the
-- character, container item or container prop that the inventory belongs to, which the
-- `character_id`, `instance_id` and `container_id` fields of the inventory name. An
-- inventory without any of them holds the instance without saving it there. Without an
-- inventory the instance is held by nothing, which is how it is when it lies in the world
-- or has been taken out of its inventory. Marks the instance as changed.
-- @param item_obj [Item]
-- @param inventory=nil [Inventory]
function Item.set_holder(item_obj, inventory)
  if istable(inventory) then
    item_obj.character_id = inventory.character_id
    item_obj.parent_id = inventory.instance_id
    item_obj.container_id = inventory.container_id
  else
    item_obj.character_id = nil
    item_obj.parent_id = nil
    item_obj.container_id = nil
  end

  Item.mark_dirty(item_obj)
end

--- Marks an instance as changed, so that it is written to the database with the next
-- save if its row has changed. Server-side only.
-- @param item_obj [Item]
function Item.mark_dirty(item_obj)
  if Item.is_instance(item_obj) then
    dirty[item_obj] = true
    item_obj.save_failures = nil
  end
end

--- Finds the outermost loaded container item that an instance is inside of, going from
-- container item to container item through their `parent_id` fields. Server-side only.
-- @param item_obj [Item]
-- @return [Item the outermost container item, or the instance itself if it is not inside
--   of one; Number how many container items deep the instance is]
function Item.get_outermost(item_obj)
  local depth = 0

  while item_obj.parent_id and depth < 32 do
    local parent = instances[item_obj.parent_id]

    if !parent then break end

    item_obj = parent
    depth = depth + 1
  end

  return item_obj, depth
end

--- Builds the row of an instance as it is now.
-- @param item_obj [Item]
-- @return [Map the values of the columns, nil if the instance is in an inventory that is
--   not saved, false if it is nowhere]
function Item.to_record(item_obj)
  local record = {
    template_id = item_obj.id,
    data = encode(own_data(item_obj)),
    overrides = encode(item_obj.overrides)
  }

  local entity = item_obj.entity
  local world = item_obj.world_position

  if (IsValid(entity) and !entity:IsMarkedForDeletion()) or world then
    local pos, ang, dropper

    if IsValid(entity) then
      pos, ang, dropper = entity:GetPos(), entity:GetAngles(), entity.dropped_by
      item_obj.world_place = place_of(entity)
    else
      pos, ang, dropper = world.pos, world.ang, world.dropped_by
    end

    record.map = game.GetMap()
    record.pos_x, record.pos_y, record.pos_z = round(pos.x), round(pos.y), round(pos.z)
    record.pitch, record.yaw, record.roll = round(ang.p), round(ang.y), round(ang.r)

    if istable(dropper) then
      record.dropped_by_character_id = tonumber(dropper.character_id)
      record.dropped_by_steam_id = dropper.steam_id
    end
  elseif item_obj.character_id or item_obj.parent_id or item_obj.container_id then
    record.character_id = item_obj.character_id
    record.parent_id = item_obj.parent_id
    record.container_id = item_obj.container_id
    record.map = item_obj.container_id and game.GetMap() or nil
    record.inventory_type = item_obj.inventory_type
    record.x = item_obj.x
    record.y = item_obj.y
    record.rotated = item_obj.rotated == true
  elseif item_obj.inventory_id then
    return nil
  else
    return false
  end

  return record
end

--- Turns a row into a string, so that it can be told whether it has changed.
-- @param record [Map]
-- @return [String]
local function snapshot(record)
  local parts = {}

  for index, column in ipairs(columns) do
    local value = record[column]

    parts[index] = value == nil and '\0' or tostring(value)
  end

  return table.concat(parts, '\1')
end

--- Builds an instance out of a row of the items table, or returns the loaded instance of
-- the row. A new instance is not registered as loaded.
-- @param row [Map]
-- @return [Item the instance, or nil if its template does not exist; Boolean true if the
--   instance is new]
local function restore(row)
  local instance_id = tonumber(row.id)

  if !instance_id then return end

  local loaded = instances[instance_id]

  if loaded then
    return loaded, false
  end

  local template = Item.find_by_id(row.template_id)

  if !template then
    Flux.dev_print('Item #'..instance_id..' has an unknown template: '..tostring(row.template_id))

    return
  end

  local data, removed = split_data(decode(row.data))
  local item_obj = Item.instantiate(template, instance_id, decode(row.overrides), data)

  for key in pairs(removed) do
    item_obj.data[key] = nil
  end

  item_obj.character_id = tonumber(row.character_id)
  item_obj.parent_id = tonumber(row.parent_id)
  item_obj.container_id = tonumber(row.container_id)
  item_obj.inventory_type = row.inventory_type
  item_obj.x = tonumber(row.x)
  item_obj.y = tonumber(row.y)
  item_obj.rotated = to_bool(row.rotated)

  local held = item_obj.character_id or item_obj.parent_id or item_obj.container_id

  if !held and row.pos_x != nil then
    local dropper = nil

    if row.dropped_by_steam_id != nil then
      dropper = {
        character_id = tonumber(row.dropped_by_character_id),
        steam_id = row.dropped_by_steam_id
      }
    end

    item_obj.world_position = {
      pos = Vector(tonumber(row.pos_x) or 0, tonumber(row.pos_y) or 0, tonumber(row.pos_z) or 0),
      ang = Angle(tonumber(row.pitch) or 0, tonumber(row.yaw) or 0, tonumber(row.roll) or 0),
      dropped_by = dropper
    }
  end

  local record = Item.to_record(item_obj)
  local state = record and snapshot(record) or nil

  item_obj.persisted = true
  item_obj.insert_queued = true
  item_obj.stored = state
  item_obj.queued = state

  return item_obj, true
end

--- Splits a list into lists of at most chunk_size elements.
-- @param list [List]
-- @return [List<List>]
local function chunks(list)
  local result = {}

  for i = 1, #list, chunk_size do
    result[#result + 1] = { unpack(list, i, math.min(i + chunk_size - 1, #list)) }
  end

  return result
end

--- Builds a list of placeholders for an IN (...) condition.
-- @param count [Number]
-- @return [String]
local function placeholders(count)
  return string.rep('?, ', count - 1)..'?'
end

--- Runs a SELECT on the items table.
-- @param condition [String WHERE condition with ? placeholders]
-- @param values [List values of the placeholders]
-- @param callback [Function receives the list of rows]
local function select_rows(condition, values, callback)
  local query = ActiveRecord.Database:select('items')
    query:where_raw(condition, values)
    query:callback(function(result, query_str, time, bindings)
      print_query('Item Load ('..time..'s)', query_str, bindings)

      callback(istable(result) and result or {})
    end)

    query:on_error(function()
      callback({})
    end)
  query:execute()
end

--- Loads the rows that match a condition and then, level by level, the rows inside of the
-- container items among them.
-- @param condition [String WHERE condition of the outermost rows]
-- @param values [List values of the placeholders of the condition]
-- @param take [Function receives the rows of each level and returns the List<Number> of
--   the instance ids whose contents to load next]
-- @param done [Function called once there is nothing more to load]
local function walk_tree(condition, values, take, done)
  local function load_level(parent_ids)
    if #parent_ids == 0 then
      return done()
    end

    local parts = chunks(parent_ids)
    local next_ids = {}
    local pending = #parts

    for _, part in ipairs(parts) do
      select_rows('parent_id IN ('..placeholders(#part)..')', part, function(rows)
        table.Add(next_ids, take(rows))

        pending = pending - 1

        if pending == 0 then
          load_level(next_ids)
        end
      end)
    end
  end

  select_rows(condition, values, function(rows)
    load_level(take(rows))
  end)
end

--- Loads the rows that match a condition and what is inside of the container items among
-- them, and builds their instances.
-- @param condition [String WHERE condition of the outermost items]
-- @param values [List values of the placeholders of the condition]
-- @param callback [Function receives the List<Item> of the instances]
local function load_tree(condition, values, callback)
  local loaded = {}

  walk_tree(condition, values, function(rows)
    local ids = {}

    for _, row in ipairs(rows) do
      local item_obj = restore(row)

      if item_obj then
        loaded[#loaded + 1] = item_obj
        ids[#ids + 1] = item_obj.instance_id
      end
    end

    return ids
  end, function()
    callback(loaded)
  end)
end

--- Registers loaded instances as loaded, which makes them the ones in use. An instance
-- whose row is in use already by now is replaced by the one in use. Server-side only.
-- @param items [List<Item> instances from Item.load_character]
-- @return [List<Item> the instances in use]
function Item.register_loaded(items)
  local result = {}

  for index, item_obj in ipairs(items) do
    local registered = instances[item_obj.instance_id]

    if registered then
      item_obj = registered
    else
      instances[item_obj.instance_id] = item_obj
    end

    item_obj.unloading = nil
    result[index] = item_obj
  end

  return result
end

--- Loads the items of a character from the database, along with the contents of its
-- container items. The loaded instances are not in use until they are passed to
-- `Item.register_loaded`, so that a load whose result is no longer wanted can simply be
-- dropped. Instances that are loaded already are passed as they are. Server-side only.
-- @param character_id [Number]
-- @param callback [Function receives the List<Item> of the instances]
function Item.load_character(character_id, callback)
  character_id = tonumber(character_id)

  if !character_id or !storage_ready() then
    return callback({})
  end

  load_tree('character_id = ?', { character_id }, callback)
end

--- Loads the items of the current map from the database: those lying in the world, those
-- in the container props, and what is inside of their container items. Spawns the items
-- that lie in the world and runs the 'OnMapItemsLoaded' hook. Server-side only.
-- @param callback=nil [Function receives the List<Item> of the loaded instances]
function Item.load_map(callback)
  if !storage_ready() then return end

  local condition = 'map = ? AND character_id IS NULL AND parent_id IS NULL'

  load_tree(condition, { game.GetMap() }, function(items)
    items = Item.register_loaded(items)

    for _, item_obj in ipairs(items) do
      local world = item_obj.world_position

      if world then
        item_obj.world_position = nil

        Item.spawn(world.pos, world.ang, item_obj, world.dropped_by or false, true)
      end
    end

    --- Called on the server once the items of the current map have been loaded from the
    -- database, after those that lie in the world have been spawned. Handlers put the
    -- other items where they belong: the Containers plugin claims the items of its
    -- container props, and the Inventory plugin puts the contents of container items
    -- into the inventories of their containers.
    -- @param items [List<Item> The loaded instances, the contents of container items
    --   among them]
    hook.Run('OnMapItemsLoaded', items)

    if callback then
      callback(items)
    end
  end)
end

--- Unregisters an instance, so that the server forgets it, and tells the clients that
-- know it to forget it too. With `delete` the row of the instance is deleted with the next
-- save. Changes that are not written yet are lost; use Item.unload to keep them.
-- Server-side only.
-- @param item_obj [Item]
-- @param delete=false [Boolean]
function Item.forget(item_obj, delete)
  if instances[item_obj.instance_id] == item_obj then
    instances[item_obj.instance_id] = nil
  end

  dirty[item_obj] = nil

  if delete and item_obj.insert_queued then
    deleted[item_obj.instance_id] = true
  end

  item_obj.persisted = false
  item_obj.insert_queued = false
  item_obj.unloading = nil

  Item.network_forget(item_obj)
end

--- Forgets an unloaded instance once nothing about it is waiting to be written.
-- @param item_obj [Item]
local function forget_if_written(item_obj)
  if item_obj.unloading and (item_obj.writes_in_flight or 0) == 0 and !dirty[item_obj] then
    Item.forget(item_obj)
  end
end

--- Unloads instances because nothing uses them anymore: the clients forget them right
-- away, their changes are written, and the server forgets them once that has worked.
-- Server-side only.
-- @param items [List<Item>]
function Item.unload(items)
  local unloading = {}

  for _, item_obj in ipairs(items) do
    if instances[item_obj.instance_id] == item_obj then
      item_obj.unloading = true
      dirty[item_obj] = true
      unloading[#unloading + 1] = item_obj

      Item.network_forget(item_obj)
    end
  end

  Item.save(unloading)

  for _, item_obj in ipairs(unloading) do
    forget_if_written(item_obj)
  end
end

--- Collects the values of a row for an insert or update query.
-- @param query [ActiveRecord::Query]
-- @param record [Map]
-- @param method [String 'insert' or 'update']
local function add_values(query, record, method)
  local type_to_db = ActiveRecord.type_to_db

  for _, column in ipairs(columns) do
    local value = record[column]

    if column == 'rotated' then
      value = type_to_db(value == true, 'boolean')
    end

    query[method](query, column, value)
  end
end

--- Logs a query that changes the items table.
-- @param label [String]
-- @return [Function query callback]
local function log_query(label)
  return function(_result, query_str, time, bindings)
    print_query('Item '..label..' ('..time..'s)', query_str, bindings)
  end
end

--- Starts the insert or update query of a row.
-- @param entry [Map the item, its record, its state and whether it is new]
-- @param now [String date-time]
-- @param on_success [Function]
-- @param on_error [Function]
local function write_entry(entry, now, on_success, on_error)
  local item_obj, record = entry.item, entry.record
  local query

  if entry.insert then
    query = ActiveRecord.Database:insert('items')
    query:insert('id', item_obj.instance_id)
    add_values(query, record, 'insert')
    query:insert('created_at', now)
    query:insert('updated_at', now)
  else
    query = ActiveRecord.Database:update('items')
    query:where('id', item_obj.instance_id)
    add_values(query, record, 'update')
    query:update('updated_at', now)
  end

  query.without_id = true
  query:callback(function(...)
    log_query(entry.insert and 'Create' or 'Update')(...)

    if on_success then on_success() end
  end)

  query:on_error(on_error)
  query:execute()
end

--- Starts the delete queries of rows.
-- @param ids [List<Number>]
-- @param on_error [Function]
local function delete_rows(ids, on_error)
  for _, part in ipairs(chunks(ids)) do
    local query = ActiveRecord.Database:delete('items')
      query:where_raw('id IN ('..placeholders(#part)..')', part)
      query:callback(log_query('Delete'))
      query:on_error(on_error)
    query:execute()
  end
end

--- Takes note that the row of an entry has been written.
-- @param entry [Map]
local function written(entry)
  local item_obj = entry.item

  item_obj.writes_in_flight = item_obj.writes_in_flight - 1
  item_obj.stored = entry.state
  item_obj.solo_save = nil

  if entry.insert then
    item_obj.persisted = true
  end

  forget_if_written(item_obj)
end

--- Takes note that the row of an entry could not be written, and marks the instance again
-- so that the next save tries once more. An instance whose own statement has failed is
-- written on its own the next time; after a few failures it waits for its next change.
-- @param entry [Map]
-- @param culprit [Boolean true if the statement of the entry itself has failed]
-- @param failures [List<Item> collects the instances that could not be written]
local function not_written(entry, culprit, failures)
  local item_obj = entry.item

  item_obj.writes_in_flight = item_obj.writes_in_flight - 1
  item_obj.queued = item_obj.stored
  item_obj.insert_queued = item_obj.persisted

  if instances[item_obj.instance_id] != item_obj then return end

  failures[#failures + 1] = item_obj

  if culprit then
    item_obj.solo_save = true
    item_obj.save_failures = (item_obj.save_failures or 0) + 1
  end

  if item_obj.unloading or (item_obj.save_failures or 0) < max_retries then
    dirty[item_obj] = true
  else
    ErrorNoHalt('Item #'..item_obj.instance_id..' could not be saved and waits for its next change.\n')
  end
end

--- Writes entries and deleted rows in one transaction. The rows count as written once the
-- transaction has been committed.
-- @param entries [List<Map>]
-- @param deleted_ids [List<Number>]
-- @param failures [List<Item> collects the instances that could not be written]
local function write_batch(entries, deleted_ids, failures)
  local adapter = ActiveRecord.adapter
  local failed = {}
  local first_failed = nil
  local deletes_failed = false
  local now = to_datetime(os.time())

  for _, entry in ipairs(entries) do
    entry.item.writes_in_flight = (entry.item.writes_in_flight or 0) + 1
  end

  writes_pending = writes_pending + 1

  local function finish(committed)
    writes_pending = writes_pending - 1

    -- PostgreSQL rolls the whole transaction back once a statement has failed.
    local aborted = adapter:is_postgres() and (first_failed != nil or deletes_failed)

    for _, entry in ipairs(entries) do
      if committed and !aborted and !failed[entry] then
        written(entry)
      else
        local culprit = failed[entry] and (!adapter:is_postgres() or entry == first_failed)

        not_written(entry, culprit, failures)
      end
    end

    if !committed or aborted or deletes_failed then
      for _, instance_id in ipairs(deleted_ids) do
        deleted[instance_id] = true
      end
    end
  end

  adapter:raw_query('BEGIN;')

  local success, exception = pcall(function()
    for _, entry in ipairs(entries) do
      write_entry(entry, now, nil, function()
        failed[entry] = true
        first_failed = first_failed or entry
      end)
    end

    delete_rows(deleted_ids, function()
      deletes_failed = true
    end)
  end)

  if !success then
    error_with_traceback(tostring(exception))

    local function rolled_back() finish(false) end

    adapter:raw_query('ROLLBACK;', rolled_back, nil, nil, rolled_back)

    return
  end

  adapter:raw_query('COMMIT;', function() finish(true) end, nil, nil, function() finish(false) end)
end

--- Writes an entry on its own, outside of a transaction.
-- @param entry [Map]
-- @param failures [List<Item> collects the instances that could not be written]
local function write_solo(entry, failures)
  entry.item.writes_in_flight = (entry.item.writes_in_flight or 0) + 1
  writes_pending = writes_pending + 1

  write_entry(entry, to_datetime(os.time()), function()
    writes_pending = writes_pending - 1
    written(entry)
  end, function()
    writes_pending = writes_pending - 1
    not_written(entry, true, failures)
  end)
end

--- Writes the changes to the database: inserts the new instances, updates the changed rows
-- and deletes the rows of the removed instances, all in one transaction. Instances whose
-- own statement failed the last time are written on their own. Without a list, every
-- marked instance is written. An instance that is held by nothing and lies nowhere is
-- removed instead. Server-side only.
-- @param items=nil [List<Item> the instances to write; all marked instances if nil]
-- @param sync=false [Boolean wait for the writes started before, then write and wait until
--   the database has run the queries]
-- @return [List<Item> in sync mode, the instances that could not be written]
function Item.save(items, sync)
  if !storage_ready() then return {} end

  if sync then
    local drained = ActiveRecord.adapter:wait_until(function() return writes_pending == 0 end)

    if !drained then
      ErrorNoHalt('Earlier item writes are still running, the items are written anyway.\n')
    end

    return with_sync(function() return Item.save(items) end) or {}
  end

  local candidates = {}

  if items then
    for _, item_obj in ipairs(items) do
      if dirty[item_obj] then
        candidates[#candidates + 1] = item_obj
      end
    end
  else
    for item_obj in pairs(dirty) do
      candidates[#candidates + 1] = item_obj
    end
  end

  local batch, solo = {}, {}

  for _, item_obj in ipairs(candidates) do
    dirty[item_obj] = nil

    if instances[item_obj.instance_id] == item_obj then
      local record = Item.to_record(item_obj)

      if record == false then
        Item.remove(item_obj)
      elseif record then
        local too_long = (record.data and #record.data > max_serialized_length)
          or (record.overrides and #record.overrides > max_serialized_length)

        if too_long then
          ErrorNoHalt('Item #'..item_obj.instance_id..' has more custom data than can be saved.\n')
        else
          local state = snapshot(record)
          local entry = {
            item = item_obj,
            record = record,
            state = state,
            insert = !item_obj.insert_queued
          }

          if entry.insert or state != item_obj.queued then
            local _outermost, depth = Item.get_outermost(item_obj)

            entry.depth = depth
            item_obj.queued = state
            item_obj.insert_queued = true

            if item_obj.solo_save then
              solo[#solo + 1] = entry
            else
              batch[#batch + 1] = entry
            end
          end
        end
      end
    end
  end

  local deleted_ids = table.GetKeys(deleted)
  local failures = {}

  table.Empty(deleted)

  -- Container items go before their contents, so that the contents can refer to them.
  local function by_depth(a, b)
    if a.insert != b.insert then return a.insert end

    return (a.depth or 0) < (b.depth or 0)
  end

  table.sort(batch, by_depth)
  table.sort(solo, by_depth)

  if #batch > 0 or #deleted_ids > 0 then
    write_batch(batch, deleted_ids, failures)
  end

  for _, entry in ipairs(solo) do
    write_solo(entry, failures)
  end

  return failures
end

--- Marks the items lying in the world that have moved since they were last written, so
-- that the next save writes them. Server-side only.
function Item.mark_world_dirty()
  for _, entity in ipairs(ents.FindByClass('fl_item')) do
    local item_obj = entity.item

    if item_obj and item_obj.world_place != place_of(entity) then
      Item.mark_dirty(item_obj)
    end
  end
end

--- Deletes the items of a character from the database, along with what is inside of its
-- container items, and forgets the instances that are loaded. Items that the character has
-- dropped into the world no longer remember it. Server-side only.
-- @param character_id [Number]
function Item.delete_character_items(character_id)
  character_id = tonumber(character_id)

  if !character_id or !storage_ready() then return end

  local owned = {}

  for _, item_obj in pairs(instances) do
    if item_obj.character_id == character_id then
      owned[#owned + 1] = item_obj
    end
  end

  for _, item_obj in ipairs(owned) do
    Item.remove(item_obj)
  end

  for _, entity in ipairs(ents.FindByClass('fl_item')) do
    local dropper = entity.dropped_by

    if istable(dropper) and tonumber(dropper.character_id) == character_id then
      dropper.character_id = nil

      if entity.item then
        Item.mark_dirty(entity.item)
      end
    end
  end

  local query = ActiveRecord.Database:update('items')
    query:where('dropped_by_character_id', character_id)
    query:update('dropped_by_character_id', nil)
    query:callback(log_query('Update'))
  query:execute()

  local ids = {}

  walk_tree('character_id = ?', { character_id }, function(rows)
    local level = {}

    for _, row in ipairs(rows) do
      local instance_id = tonumber(row.id)

      if instance_id and !ids[instance_id] then
        ids[instance_id] = true
        level[#level + 1] = instance_id
      end
    end

    return level
  end, function()
    delete_rows(table.GetKeys(ids))
  end)
end

timer.Create('fl_items_save', save_interval, 0, function()
  Item.save()
end)
