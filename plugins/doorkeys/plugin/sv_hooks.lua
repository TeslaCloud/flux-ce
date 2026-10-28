--- Server side of the Door Keys plugin: lets the holders of a key lock its doors and handles
-- what the door menu and the key molding kit ask for.

--- Lets players lock and unlock doors that one of their keys belongs to.
-- @param actor [Player player trying to lock the door]
-- @param entity [Entity door]
-- @return [Boolean true if the player has a key for the door, nil otherwise]
function PLUGIN:PlayerCanLockDoor(actor, entity)
  local keys = actor:find_items('key')

  if keys then
    local door_id = entity:MapCreationID()

    for _, key_item in pairs(keys) do
      if table.HasValue(key_item:get_data('doors', {}), door_id) then
        return true
      end
    end
  end
end

local function can_manage_keys(actor, entity)
  return actor:can('manage_doors') and isentity(entity) and IsValid(entity) and entity:is_door()
end

local function find_key(instance_id)
  local item_obj = isnumber(instance_id) and Item.find_instance_by_id(instance_id)

  if item_obj and item_obj.id == 'key' then
    return item_obj
  end
end

local function give_new_item(actor, item_obj)
  local success, error_text = actor:add_item(item_obj)

  if !success then
    Item.remove(item_obj)
    actor:notify(error_text or 'error.inventory.no_space')

    return false
  end

  return true
end

Cable.receive('fl_key_create', function(actor, entity)
  if !can_manage_keys(actor, entity) then return end

  local item_obj = Item.create('key')

  if !item_obj then return end

  item_obj:set_data('doors', { entity:MapCreationID() })

  if give_new_item(actor, item_obj) then
    actor:notify('notification.key.create')
  end
end)

Cable.receive('fl_key_copy', function(actor, instance_id)
  local source_item = find_key(instance_id)

  if !source_item or !actor:has_item_by_id(source_item.instance_id) then return end
  if !actor:has_item('key_molding_kit') then return end

  local has_blank, blank_item = actor:has_item('key_blank')
  local blank_inventory = has_blank and blank_item and Inventories.find(blank_item.inventory_id)

  if !blank_inventory then return end

  local item_obj = Item.create('key')

  if !item_obj then return end

  item_obj:set_data('doors', table.Copy(source_item:get_data('doors', {})))

  --- Called when a player copies a key with a key molding kit, before the copy is given to
  -- them. Lets plugins change the copy.
  -- @param actor [Player player copying the key]
  -- @param item_obj [Item the copy]
  -- @param source_item [Item the key that is copied]
  hook.Run('OnKeyCopy', actor, item_obj, source_item)

  if !give_new_item(actor, item_obj) then return end

  hook.Run('PreItemTransfer', blank_item, nil, blank_inventory)

  blank_inventory:take_item_by_id(blank_item.instance_id)
  blank_inventory:sync()

  hook.Run('ItemTransferred', blank_item, nil, blank_inventory)

  Item.remove(blank_item)

  actor:notify('notification.key.create')
end)

Cable.receive('fl_key_remove', function(actor, instance_id, entity)
  if !can_manage_keys(actor, entity) then return end

  local item_obj = find_key(instance_id)

  if !item_obj then return end

  local doors = table.Copy(item_obj:get_data('doors', {}))

  table.RemoveByValue(doors, entity:MapCreationID())

  item_obj:set_data('doors', doors)
  actor:notify('notification.key.remove')
end)

Cable.receive('fl_key_add', function(actor, instance_id, entity)
  if !can_manage_keys(actor, entity) then return end

  local item_obj = find_key(instance_id)

  if !item_obj then return end

  local door_id = entity:MapCreationID()
  local doors = table.Copy(item_obj:get_data('doors', {}))

  if !table.HasValue(doors, door_id) then
    table.insert(doors, door_id)
  end

  item_obj:set_data('doors', doors)
  actor:notify('notification.key.add')
end)

Cable.receive('fl_key_show_list', function(actor, entity)
  if !can_manage_keys(actor, entity) then return end

  local door_id = entity:MapCreationID()
  local keys = {}
  local instances = Item.find_all_instances('key')

  if instances then
    for instance_id, key_item in pairs(instances) do
      if table.HasValue(key_item:get_data('doors', {}), door_id) then
        Item.network_item(actor, instance_id)
        table.insert(keys, instance_id)
      end
    end
  end

  Cable.send(actor, 'fl_key_show_list', keys, entity)
end)
