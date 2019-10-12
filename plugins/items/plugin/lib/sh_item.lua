mod 'Item'

local stored = Item.stored or {}
local instances = Item.instances or {}
local sorted = Item.sorted or {}
local entities = Item.entities or {}

-- Item Templates storage.
Item.stored = stored

-- Actual items.
Item.instances = instances

-- Instances table indexed by instance ID.
-- For quicker item lookups.
Item.sorted = sorted

-- Items currently dropped and lying on the ground.
Item.entities = entities

function Item.all()
  return stored
end

function Item.get_instances()
  return instances
end

function Item.get_sorted()
  return sorted
end

function Item.get_entities()
  return entities
end

function Item.register(id, data)
  if !data then return end

  if !isstring(data.name) and isstring(data.print_name) then
    data.name = data.print_name
  end

  if !isstring(id) and !isstring(data.name) then
    error_with_traceback('Attempt to register an item without a valid ID!')
    return
  end

  if !id then
    id = data.name:to_id()
  end

  add_debug_metric('items', tostring(id))

  data.id = id
  data.name = data.name or 'Unknown Item'
  data.print_name = data.print_name or data.name
  data.description = data.description or 'This item has no description!'
  data.weight = data.weight or 1
  data.width = data.width or 1
  data.height = data.height or 1
  data.stackable = data.stackable or false
  data.pocket_size = data.pocket_size or false
  data.max_stack = data.max_stack or 64
  data.model = data.model or 'models/props_lab/cactus.mdl'
  data.skin = data.skin or 0
  data.color = data.color or nil
  data.cost = data.cost or 0
  data.special_color = data.special_color or nil
  data.category = data.category or 'item.category.other'
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

  stored[id] = data
  instances[id] = instances[id] or {}
end

function Item.to_saveable(item_table)
  if !item_table then return end

  local save_table = {
    id = item_table.id,
    name = item_table.name,
    print_name = item_table.print_name,
    description = item_table.description,
    weight = item_table.weight,
    width = item_table.width,
    height = item_table.height,
    stackable = item_table.stackable,
    pocket_size = item_table.pocket_size,
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
    max_uses = item_table.max_uses,
    uses = item_table.uses
  }

  hook.run('PreItemSave', item_table, save_table)

  return save_table
end

-- Find item's template by it's ID.
function Item.find_by_id(id)
  for k, v in pairs(stored) do
    if k == id or v.id == id then
      return v
    end
  end
end

-- Find all instances of certain template ID.
function Item.find_all_instances(id)
  if instances[id] then
    return instances[id]
  end
end

-- Finds instance by it's ID.
function Item.find_instance_by_id(instance_id)
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
function Item.find_by_instance_id(instance_id)
  if !instance_id then return end

  if !sorted[instance_id] then
    sorted[instance_id] = Item.find_instance_by_id(instance_id)
  end

  return sorted[instance_id]
end

function Item.find(name)
  if isnumber(name) then
    return Item.find_instance_by_id(name)
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

function Item.generate_id()
  instances.count = instances.count or 0
  instances.count = instances.count + 1

  return instances.count
end

function Item.create(id, data, forced_id)
  local item_table = Item.find_by_id(id)

  if item_table then
    local item_id = forced_id or Item.generate_id()

    instances[id] = instances[id] or {}
    instances[id][item_id] = table.Copy(item_table)

    if istable(data) then
      table.safe_merge(instances[id][item_id], data)
    end

    instances[id][item_id].instance_id = item_id

    if SERVER then
      hook.run('OnItemCreated', instances[id][item_id])

      Item.async_save()
      Cable.send(nil, 'fl_items_new_instance', id, (data or 1), item_id)
    end

    return instances[id][item_id]
  end
end

function Item.remove(instance_id)
  local item_table = (istable(instance_id) and instance_id) or Item.find_instance_by_id(instance_id)

  if item_table and Item.is_instance(item_table) then
    if IsValid(item_table.entity) then
      item_table.entity:Remove()
    end

    instances[item_table.id][item_table.instance_id] = nil

    if SERVER then
      Item.async_save()
    end

    Flux.dev_print('Removed item instance ID: '..item_table.instance_id)
  end
end

function Item.is_instance(item_table)
  if !istable(item_table) then return end

  return (item_table.instance_id or ITEM_TEMPLATE) > ITEM_INVALID
end

function Item.include_items(directory)
  Pipeline.include_folder('item', directory)
end

local item_categories = {}

function Item.set_category_icon(category, icon)
  item_categories[category] = icon
end

function Item.get_category_icon(category)
  return item_categories[category] or 'icon16/bricks.png'
end

Item.set_category_icon('item.category.ammo', 'icon16/box.png')
Item.set_category_icon('item.category.consumables', 'icon16/cake.png')
Item.set_category_icon('item.category.throwable', 'icon16/bomb.png')
Item.set_category_icon('item.category.weapon', 'icon16/gun.png')
Item.set_category_icon('item.category.clothing', 'icon16/user.png')
Item.set_category_icon('item.category.cards', 'icon16/vcard.png')
Item.set_category_icon('item.category.other', 'icon16/bricks.png')
Item.set_category_icon('item.category.equipment', 'icon16/package.png')

if SERVER then
  function Item.load()
    local loaded = Data.load_schema('items/instances', {})

    if loaded and !table.IsEmpty(loaded) then
      -- Returns functions to instances table after loading.
      for id, instance_table in pairs(loaded) do
        local item_table = Item.find_by_id(id)

        if item_table then
          for k, v in pairs(instance_table) do
            local new_item = table.Copy(item_table)

            table.safe_merge(new_item, v)

            loaded[id][k] = new_item
          end
        end
      end

      instances = loaded
      Item.instances = loaded
    end

    local loaded = Data.load_schema('items/entities', {})

    if loaded and !table.IsEmpty(loaded) then
      for id, instance_table in pairs(loaded) do
        for k, v in pairs(instance_table) do
          if instances[id] and instances[id][k] then
            Item.spawn(v.position, v.angles, instances[id][k])
          else
            loaded[id][k] = nil
          end
        end
      end

      entities = loaded
      Item.entities = loaded
    end
  end

  function Item.save_instances()
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
            to_save[k][k2] = Item.to_saveable(v2)
          end
        end
      end
    end

    Data.save_schema('items/instances', to_save)
  end

  function Item.save_entities()
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

  function Item.save_all()
    Item.save_instances()
    Item.save_entities()
  end

  function Item.async_save()
    local handle = coroutine.create(Item.save_all)
    coroutine.resume(handle)
  end

  function Item.async_save_instances()
    local handle = coroutine.create(Item.save_instances)
    coroutine.resume(handle)
  end

  function Item.async_save_entities()
    local handle = coroutine.create(Item.save_entities)
    coroutine.resume(handle)
  end

  function Item.network_item_data(player, item_table)
    if Item.is_instance(item_table) then
      Cable.send(player, 'fl_items_data', item_table.id, item_table.instance_id, item_table.data)
    end
  end

  function Item.network_item(player, instance_id)
    Cable.send(player, 'fl_items_network', instance_id, Item.to_saveable(Item.find_instance_by_id(instance_id)))
  end

  function Item.network_entity_data(player, ent)
    if IsValid(ent) then
      Cable.send(player, 'fl_items_ent_data', ent:EntIndex(), ent.item.id, ent.item.instance_id)
    end
  end

  -- A function to send info about items in the world.
  function Item.send_to_player(player)
    local item_ents = ents.FindByClass('fl_item')

    for k, v in ipairs(item_ents) do
      if v.item then
        Item.network_item(player, v.item.instance_id)
      end
    end

    hook.run_client(player, 'OnItemDataReceived')
  end

  function Item.spawn(position, angles, item_table)
    if !position or !istable(item_table) then
      error_with_traceback('No position or item table is not a table!')
      return
    end

    if !Item.is_instance(item_table) then
      error_with_traceback('Cannot spawn non-instantiated item!')
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
    Item.network_item(nil, item_table.instance_id)

    entities[item_table.id] = entities[item_table.id] or {}
    entities[item_table.id][item_table.instance_id] = entities[item_table.id][item_table.instance_id] or {}
    entities[item_table.id][item_table.instance_id] = {
      position = position,
      angles = angles
    }

    Item.async_save_entities()

    return ent, item_table
  end

  Cable.receive('fl_items_data_request', function(player, ent_index)
    local ent = Entity(ent_index)

    if IsValid(ent) then
      Item.network_entity_data(player, ent)
    end
  end)
else
  Cable.receive('fl_items_data', function(id, instance_id, data)
    if istable(instances[id][instance_id]) then
      instances[id][instance_id].data = data
    end
  end)

  Cable.receive('fl_items_network', function(instance_id, item_table)
    if item_table and stored[item_table.id] then
      local new_table = table.Copy(stored[item_table.id])
      table.safe_merge(new_table, item_table)

      instances[new_table.id][instance_id] = new_table
    else
      print('Failed to receive item instance #'..(instance_id or '')..', please report that.')
    end
  end)

  Cable.receive('fl_items_ent_data', function(ent_index, id, instance_id)
    local ent = Entity(ent_index)

    if IsValid(ent) then
      local item_table = instances[id][instance_id]

      if item_table == nil then
        return Cable.send('fl_items_data_request', ent_index)
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

  Cable.receive('fl_items_new_instance', function(id, data, item_id)
    Item.create(id, data, item_id)
  end)
end

Pipeline.register('item', function(id, file_name, pipe)
  ITEM = ItemBase.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then ITEM = nil return end

  ITEM:register() ITEM = nil
end)
