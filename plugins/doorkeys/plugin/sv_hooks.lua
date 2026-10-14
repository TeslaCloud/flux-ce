--- Lets players lock and unlock doors that one of their keys belongs to.
-- @param actor [Player player trying to lock the door]
-- @param entity [Entity door]
-- @return [Boolean true if the player has a key for the door, nil otherwise]
function PLUGIN:PlayerCanLockDoor(actor, entity)
  local keys = actor:find_items('key')

  if keys then
    local door_id = entity:MapCreationID()

    for k, v in pairs(keys) do
      if table.HasValue(v:get_data('doors', {}), door_id) then
        return true
      end
    end
  end
end

Cable.receive('fl_key_create', function(actor, entity)
  local doors = {
    entity:MapCreationID()
  }

  local item_table = Item.create('key')
  item_table:set_data('doors', doors)

  actor:add_item_by_id(item_table.instance_id)
  actor:notify('notification.key.create')
end)

Cable.receive('fl_key_copy', function(actor, instance_id)
  local source_item = Item.find_instance_by_id(instance_id)
  local item_table = Item.create('key')
  item_table:set_data('doors', source_item:get_data('doors'))

  hook.Run('OnKeyCopy', actor, item_table, source_item)

  actor:add_item_by_id(item_table.instance_id)
  actor:take_item('key_blank')
  actor:notify('notification.key.create')
end)

Cable.receive('fl_key_remove', function(actor, instance_id, entity)
  local door_id = entity:MapCreationID()
  local item_table = Item.find_instance_by_id(instance_id)
  local doors = item_table:get_data('doors', {})

  table.RemoveByValue(doors, door_id)

  item_table:set_data('doors', doors)
  actor:notify('notification.key.remove')
end)

Cable.receive('fl_key_add', function(actor, instance_id, entity)
  local door_id = entity:MapCreationID()
  local item_table = Item.find_instance_by_id(instance_id)
  local doors = item_table:get_data('doors', {})

  if !table.HasValue(doors, door_id) then
    table.insert(doors, door_id)
  end

  item_table:set_data('doors', doors)
  actor:notify('notification.key.add')
end)

Cable.receive('fl_key_show_list', function(actor, entity)
  local door_id = entity:MapCreationID()
  local keys = {}
  local instances = Item.find_all_instances('key')

  if instances then
    for k, v in pairs(instances) do
      if table.HasValue(v:get_data('doors', {}), door_id) then
        Item.network_item(actor, k)
        table.insert(keys, k)
      end
    end
  end

  Cable.send(actor, 'fl_key_show_list', keys, entity)
end)
