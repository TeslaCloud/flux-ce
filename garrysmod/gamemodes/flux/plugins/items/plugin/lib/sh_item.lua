library 'item'

local stored = item.stored or {}
local instances = item.instances or {}
local sorted = item.sorted or {}
local entities = item.entities or {}

-- Item Templates storage.
item.stored = stored

-- Actual items.
item.instances = instances

-- Instances table indexed by instance ID.
-- For quicker item lookups.
item.sorted = sorted

-- Items currently dropped and lying on the ground.
item.entities = entities

function item.all()
  return stored
end

function item.get_instances()
  return instances
end

function item.get_sorted()
  return sorted
end

function item.get_entities()
  return entities
end

function item.register(id, data)
  if !data then return end

  if !isstring(data.name) and isstring(data.print_name) then
    data.name = data.print_name
  end

  if !isstring(id) and !isstring(data.name) then
    ErrorNoHalt('Attempt to register an item without a valid ID!')
    debug.Trace()

    return
  end

  if !id then
    id = data.name:to_id()
  end

  Flux.dev_print('Registering item: '..tostring(id))

  data.id = id
  data.name = data.name or 'Unknown Item'
  data.print_name = data.print_name or data.name
  data.description = data.description or 'This item has no description!'
  data.weight = data.weight or 1
  data.stackable = data.stackable or false
  data.max_stack = data.max_stack or 64
  data.model = data.model or 'models/props_lab/cactus.mdl'
  data.skin = data.skin or 0
  data.color = data.color or nil
  data.cost = data.cost or 0
  data.special_color = data.special_color or nil
  data.category = data.category or t('item.category.other')
  data.is_base = data.is_base or false
  data.instance_id = ITEM_TEMPLATE
  data.data = data.data or {}
  data.custom_buttons = data.custom_buttons or {}
  data.action_sounds = data.action_sounds or {}
  data.use_text = data.use_text
  data.take_text = data.take_text
  data.cancel_text = data.cancel_text
  data.use_icon = data.use_icon
  data.take_icon = data.take_icon
  data.cancel_icon = data.cancel_icon
  data.slot_id = data.slot_id

  stored[id] = data
  instances[id] = instances[id] or {}
end

function item.to_save(item_table)
  if !item_table then return end

  return {
    id = item_table.id,
    name = item_table.name,
    print_name = item_table.print_name,
    description = item_table.description,
    weight = item_table.weight,
    stackable = item_table.stackable,
    max_stack = item_table.max_stack,
    model = item_table.model,
    skin = item_table.skin,
    color = item_table.color,
    cost = item_table.cost,
    special_color = item_table.special_color,
    is_base = item_table.is_base,
    instance_id = item_table.instance_id,
    data = item_table.data,
    action_sounds = item_table.action_sounds,
    use_text = item_table.use_text,
    take_text = item_table.take_text,
    cancel_text = item_table.cancel_text,
    use_icon = item_table.use_icon,
    take_icon = item_table.take_icon,
    cancel_icon = item_table.cancel_icon,
    slot_id = item_table.slot_id,
    inventory_type = item_table.inventory_type
  }
end

-- Find item's template by it's ID.
function item.find_by_id(id)
  for k, v in pairs(stored) do
    if k == id or v.id == id then
      return v
    end
  end
end

-- Find all instances of certain template ID.
function item.find_all_instances(id)
  if instances[id] then
    return instances[id]
  end
end

-- Finds instance by it's ID.
function item.find_instance_by_id(instance_id)
  for item_id, item_instances in pairs(instances) do
    if istable(item_instances) then
      for k, item_table in pairs(item_instances) do
        if item_table.instance_id == instance_id then
          return item_table
        end
      end
    end
  end
end

-- Finds an item template that belongs to certain instance ID.
function item.find_by_instance_id(instance_id)
  if !instance_id then return end

  if !sorted[instance_id] then
    sorted[instance_id] = item.find_instance_by_id(instance_id)
  end

  return sorted[instance_id]
end

function item.find(name)
  if isnumber(name) then
    return item.find_instance_by_id(name)
  end

  if stored[id] then
    return stored[id]
  end

  for k, v in pairs(stored) do
    if v.id and v.name and v.print_name then
      if v.id == name or v.name:find(name) or v.print_name:find(name) then
        return v
      end

      if CLIENT then
        if v.print_name:find(name) then
          return v
        end
      end
    end
  end
end

function item.generate_id()
  instances.count = instances.count or 0
  instances.count = instances.count + 1

  return instances.count
end

function item.new(id, data, forced_id)
  local item_table = item.find_by_id(id)

  if item_table then
    local item_id = forced_id or item.generate_id()

    instances[id] = instances[id] or {}
    instances[id][item_id] = table.Copy(item_table)

    if istable(data) then
      table.safe_merge(instances[id][item_id], data)
    end

    instances[id][item_id].instance_id = item_id

    if SERVER then
      item.async_save()
      cable.send(nil, 'fl_items_new_instance', id, (data or 1), item_id)
    end

    return instances[id][item_id]
  end
end

function item.remove(instance_id)
  local item_table = (istable(instance_id) and instance_id) or item.find_instance_by_id(instance_id)

  if item_table and item.is_instance(item_table) then
    if IsValid(item_table.entity) then
      item_table.entity:Remove()
    end

    instances[item_table.id][item_table.instance_id] = nil

    if SERVER then
      item.async_save()
    end

    Flux.dev_print('Removed item instance ID: '..item_table.instance_id)
  end
end

function item.is_instance(item_table)
  if !istable(item_table) then return end

  return (item_table.instance_id or ITEM_TEMPLATE) > ITEM_INVALID
end

function item.create_base(name)
  class(name, Item)
end

function item.include_items(directory)
  pipeline.include_folder('item', directory)
end

if SERVER then
  function item.load()
    local loaded = Data.load_schema('items/instances', {})

    if loaded and table.Count(loaded) > 0 then
      -- Returns functions to instances table after loading.
      for id, instance_table in pairs(loaded) do
        local item_table = item.find_by_id(id)

        if item_table then
          for k, v in pairs(instance_table) do
            local new_item = table.Copy(item_table)

            table.safe_merge(new_item, v)

            loaded[id][k] = new_item
          end
        end
      end

      instances = loaded
      item.instances = loaded
    end

    local loaded = Data.load_schema('items/entities', {})

    if loaded and table.Count(loaded) > 0 then
      for id, instance_table in pairs(loaded) do
        for k, v in pairs(instance_table) do
          if instances[id] and instances[id][k] then
            item.spawn(v.position, v.angles, instances[id][k])
          else
            loaded[id][k] = nil
          end
        end
      end

      entities = loaded
      item.entities = loaded
    end
  end

  function item.save_instances()
    local to_save = {}

    for k, v in pairs(instances) do
      if k == 'count' then
        to_save[k] = v
      else
        to_save[k] = {}
      end

      if istable(v) then
        for k2, v2 in pairs(v) do
          if istable(v2) then
            to_save[k][k2] = item.to_save(v2)
          end
        end
      end
    end

    Data.save_schema('items/instances', to_save)
  end

  function item.save_entities()
    local item_ents = ents.FindByClass('fl_item')

    entities = {}

    for k, v in ipairs(item_ents) do
      if IsValid(v) and v.item then
        entities[v.item.id] = entities[v.item.id] or {}

        entities[v.item.id][v.item.instance_id] = {
          position = v:GetPos(),
          angles = v:GetAngles()
        }
      end
    end

    Data.save_schema('items/entities', entities)
  end

  function item.save_all()
    item.save_instances()
    item.save_entities()
  end

  function item.async_save()
    local handle = coroutine.create(item.save_all)
    coroutine.resume(handle)
  end

  function item.async_save_instances()
    local handle = coroutine.create(item.save_instances)
    coroutine.resume(handle)
  end

  function item.async_save_entities()
    local handle = coroutine.create(item.save_entities)
    coroutine.resume(handle)
  end

  function item.network_item_data(player, item_table)
    if item.is_instance(item_table) then
      cable.send(player, 'fl_items_data', item_table.id, item_table.instance_id, item_table.data)
    end
  end

  function item.network_item(player, instance_id)
    cable.send(player, 'fl_items_network', instance_id, item.to_save(item.find_instance_by_id(instance_id)))
  end

  function item.network_entity_data(player, ent)
    if IsValid(ent) then
      cable.send(player, 'fl_items_ent_data', ent:EntIndex(), ent.item.id, ent.item.instance_id)
    end
  end

  -- A function to send info about items in the world.
  function item.send_to_player(player)
    local item_ents = ents.FindByClass('fl_item')

    for k, v in ipairs(item_ents) do
      if v.item then
        item.network_item(player, v.item.instance_id)
      end
    end

    hook.run_client(player, 'OnItemDataReceived')
  end

  function item.spawn(position, angles, item_table)
    if !position or !istable(item_table) then
      ErrorNoHalt('No position or item table is not a table!\n')

      return
    end

    if !item.is_instance(item_table) then
      ErrorNoHalt('Cannot spawn non-instantiated item!\n')

      return
    end

    local ent = ents.Create('fl_item')

    ent:set_item(item_table)

    local mins, maxs = ent:GetCollisionBounds()

    ent:SetPos(position + Vector(0, 0, maxs.z))

    if angles then
      ent:SetAngles(angles)
    end

    ent:Spawn()

    item_table:set_entity(ent)
    item.network_item(nil, item_table.instance_id)

    entities[item_table.id] = entities[item_table.id] or {}
    entities[item_table.id][item_table.instance_id] = entities[item_table.id][item_table.instance_id] or {}
    entities[item_table.id][item_table.instance_id] = {
      position = position,
      angles = angles
    }

    item.async_save_entities()

    return ent, item_table
  end

  cable.receive('fl_items_data_request', function(player, ent_index)
    local ent = Entity(ent_index)

    if IsValid(ent) then
      item.network_entity_data(player, ent)
    end
  end)
else
  cable.receive('fl_items_data', function(id, instance_id, data)
    if istable(instances[id][instance_id]) then
      instances[id][instance_id].data = data
    end
  end)

  cable.receive('fl_items_network', function(instance_id, item_table)
    if item_table and stored[item_table.id] then
      local new_table = table.Copy(stored[item_table.id])
      table.safe_merge(new_table, item_table)

      instances[new_table.id][instance_id] = new_table

      print('Received instance ID '..tostring(new_table))
    else
      print('FAILED TO RECEIVE INSTANCE ID '..(instance_id or ''))
    end
  end)

  cable.receive('fl_items_ent_data', function(ent_index, id, instance_id)
    local ent = Entity(ent_index)

    if IsValid(ent) then
      local item_table = instances[id][instance_id]

      if item_table == nil then
        return cable.send('fl_items_data_request', ent_index)
      end

      -- Client has to know this shit too I guess?
      ent:SetModel(item_table:get_model())
      ent:SetSkin(item_table.skin)
      ent:SetColor(item_table:get_color())

      -- Restore item's functions. For some weird reason they aren't properly initialized.
      table.safe_merge(ent, scripted_ents.Get('fl_item'))

      ent.item = item_table
    end
  end)

  cable.receive('fl_items_new_instance', function(id, data, item_id)
    item.new(id, data, item_id)
  end)
end

pipeline.register('item', function(id, file_name, pipe)
  ITEM = Item.new(id)

  util.include(file_name)

  if pipeline.is_aborted() then ITEM = nil return end

  ITEM:register() ITEM = nil
end)
