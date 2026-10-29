--- Client-side receivers of the Items plugin for item instances: the instances, their data
-- and the item entities that the server networks or removes, and the menu of an item entity
-- that the local player uses.

local IsValid = IsValid
local pairs = pairs
local istable = istable
local stored = Item.stored
local instances = Item.instances

Cable.receive('fl_player_use_item_entity', function(entity)
  if IsValid(entity) and entity.item then
    --- Called on the client to open the menu of an item.
    -- Here it is run when the server reports that the local player has pressed the use key
    -- on an item entity. An inventory slot runs it without the second argument when it is
    -- clicked. The Items plugin handles the hook by building the menu.
    -- @param instance_id [Number Instance id of the item]
    -- @param is_entity [Boolean true if the item lies in the world, nil if it is in an
    --   inventory; decides between the take and the drop option]
    hook.Run('PlayerUseItemMenu', entity.item.instance_id, true)
  end
end)

Cable.receive('fl_items_data', function(instance_id, data)
  local item_obj = instances[instance_id]

  if istable(item_obj) then
    item_obj.data = data
  end
end)

Cable.receive('fl_items_network', function(instance_id, fields)
  local template = istable(fields) and stored[fields.id]

  if !template then
    print('Failed to receive item instance #'..(instance_id or '')..', please report that.')

    return
  end

  local item_obj = Item.instantiate(template, instance_id, nil, nil)

  for key, value in pairs(fields) do
    item_obj[key] = value
  end

  local old_item = instances[instance_id]

  instances[instance_id] = item_obj

  if old_item and IsValid(old_item.entity) and old_item.entity.item == old_item then
    old_item.entity.item = item_obj
    item_obj.entity = old_item.entity
  end
end)

Cable.receive('fl_items_ent_data', function(ent_index, instance_id)
  local ent = Entity(ent_index)

  if !IsValid(ent) then return end

  local item_obj = instances[instance_id]

  if item_obj == nil then
    return Cable.send('fl_items_data_request', ent_index)
  end

  ent:SetModel(item_obj:get_model())
  ent:SetSkin(item_obj.skin)
  ent:SetColor(item_obj:get_color())

  Item.apply_bodygroups(ent, item_obj)

  table.safe_merge(ent, scripted_ents.Get('fl_item'))

  ent.item = item_obj
  item_obj.entity = ent
end)

Cable.receive('fl_items_remove', function(instance_id)
  Item.remove(instance_id)
end)
