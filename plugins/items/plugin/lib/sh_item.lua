--- The Item library keeps track of item templates and item instances.
-- Templates are the item classes registered from item files. The `item` pipeline, defined
-- at the end of this file, creates an `ItemBase` object for every file, runs the file with
-- that object as `ITEM` and passes it to `Item.register`. `Item.create` makes an instance
-- out of a template, with an instance id of its own, and `Item.spawn` puts an instance
-- into the world as an `fl_item` entity.
--
-- On the server the library also saves the instances and the positions of the item
-- entities (`Item.save_all`, `Item.load`) and sends instances to the clients
-- (`Item.network_item`, `Item.network_item_data`), which keep their own copies of them.
-- Plugins can add fields to what is saved and sent through the `PreItemSave` hook.
-- `Item.remove` deletes an instance for good, on the server and on every client.
--
-- An item entity remembers the character that dropped it. `Item.spawn` takes the dropper
-- as its last argument, and `Item.expect_drop` names the dropper for callers that cannot
-- pass one; the Items plugin does so whenever a player drops an item from an inventory.

mod 'Item'

local stored = Item.stored or {}
local instances = Item.instances or {}
local sorted = Item.sorted or {}
local entities = Item.entities or {}
local expected_drops = Item.expected_drops or {}

-- Item Templates storage.
Item.stored = stored

-- Actual items.
Item.instances = instances

-- Instances table indexed by instance ID.
-- For quicker item lookups.
Item.sorted = sorted

-- Items currently dropped and lying on the ground.
Item.entities = entities

Item.expected_drops = expected_drops

--- Returns all the registered item templates.
-- @return [Map item templates, keyed by item id]
function Item.all()
  return stored
end

--- Returns the storage of all item instances.
-- It is keyed by item id; each value is a hash of instance id to item instance.
-- The storage also holds a numeric 'count' field with the last generated instance id.
-- @return [Map instances]
function Item.get_instances()
  return instances
end

--- Returns the lookup cache of item instances that is filled by Item.find_by_instance_id.
-- @return [Map item instances, keyed by instance id]
function Item.get_sorted()
  return sorted
end

--- Returns saved data about the items that are lying on the ground.
-- It is keyed by item id, then by instance id; each entry has 'position' and 'angles' fields,
-- and a 'dropped_by' field if a character has dropped the item.
-- @return [Map entity data]
function Item.get_entities()
  return entities
end

--- Registers an item template, filling in defaults for every field that is not set.
-- Item files normally get here through ItemBase:register, which the 'item' pipeline calls.
-- @param id=nil [String item id; made out of data.name when omitted]
-- @param data [Item item table to store as the template]
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
  data.max_stack = data.max_stack or 1
  data.model = data.model or 'models/props_lab/cactus.mdl'
  data.skin = data.skin or 0
  data.color = data.color or nil
  data.cost = data.cost or 0
  data.special_color = data.special_color or nil
  data.background_color = data.background_color or nil
  data.category = data.category or 'item.category.other'
  data.is_base = data.is_base or false
  data.instance_id = ITEM_TEMPLATE
  data.data = data.data or {}
  data.custom_buttons = data.custom_buttons or {}
  data.action_sounds = data.action_sounds or {}
  data.use_text = data.use_text
  data.take_text = data.take_text
  data.drop_text = data.drop_text
  data.cancel_text = data.cancel_text
  data.use_icon = data.use_icon
  data.take_icon = data.take_icon
  data.drop_icon = data.drop_icon
  data.cancel_icon = data.cancel_icon
  data.destroy_text = data.destroy_text
  data.destroy_icon = data.destroy_icon
  data.model_bodygroups = data.model_bodygroups or nil
  data.icon_data = data.icon_data or nil
  data.icon_material = data.icon_material or nil

  stored[id] = data
  instances[id] = instances[id] or {}
end

--- Builds a plain table out of the item fields that are saved to disk and networked.
-- Runs the 'PreItemSave' hook so that plugins can add fields of their own.
-- @param item_obj [Item]
-- @return [Map saveable fields, or nil if no item was given]
function Item.to_saveable(item_obj)
  if !item_obj then return end

  local save_table = {
    id = item_obj.id,
    name = item_obj.name,
    print_name = item_obj.print_name,
    description = item_obj.description,
    weight = item_obj.weight,
    width = item_obj.width,
    height = item_obj.height,
    stackable = item_obj.stackable,
    pocket_size = item_obj.pocket_size,
    max_stack = item_obj.max_stack,
    model = item_obj.model,
    skin = item_obj.skin,
    color = item_obj.color,
    model_bodygroups = item_obj.model_bodygroups,
    cost = item_obj.cost,
    special_color = item_obj.special_color,
    is_base = item_obj.is_base,
    instance_id = item_obj.instance_id,
    data = item_obj.data,
    action_sounds = item_obj.action_sounds,
    use_text = item_obj.use_text,
    take_text = item_obj.take_text,
    drop_text = item_obj.drop_text,
    cancel_text = item_obj.cancel_text,
    use_icon = item_obj.use_icon,
    take_icon = item_obj.take_icon,
    drop_icon = item_obj.drop_icon,
    cancel_icon = item_obj.cancel_icon,
    destroy_text = item_obj.destroy_text,
    destroy_icon = item_obj.destroy_icon,
    max_uses = item_obj.max_uses,
    uses = item_obj.uses,
    icon_data = item_obj.icon_data,
    icon_material = item_obj.icon_material
  }

  --- Lets plugins add fields to the data of an item that is saved and sent to clients.
  -- Called by `Item.to_saveable`, which the server uses both when it saves the item
  -- instances and when it sends an instance to clients. Handlers write their fields into
  -- `save_table`; the Inventory plugin adds the position of the item in its inventory.
  -- @param item_obj [Item The item that is being saved]
  -- @param save_table [Map The fields that are going to be saved, to be modified in place]
  hook.Run('PreItemSave', item_obj, save_table)

  return save_table
end

--- Finds an item template by its id.
-- @param id [String item id]
-- @return [Item the template, or nil if not found]
function Item.find_by_id(id)
  for k, v in pairs(stored) do
    if k == id or v.id == id then
      return v
    end
  end
end

--- Finds all instances of a certain item template.
-- @param id [String item id]
-- @return [Map item instances keyed by instance id, or nil if there is no such template]
function Item.find_all_instances(id)
  if instances[id] then
    return instances[id]
  end
end

--- Finds an item instance by its instance id.
-- @param instance_id [Number]
-- @return [Item the instance, or nil if not found]
function Item.find_instance_by_id(instance_id)
  for item_id, item_instances in pairs(instances) do
    if istable(item_instances) then
      for k, item_obj in pairs(item_instances) do
        if item_obj.instance_id == instance_id then
          return item_obj
        end
      end
    end
  end
end

--- Finds an item instance by its instance id, caching the result for quicker lookups later.
-- @param instance_id [Number]
-- @return [Item the instance, or nil if not found]
function Item.find_by_instance_id(instance_id)
  if !instance_id then return end

  if !sorted[instance_id] then
    sorted[instance_id] = Item.find_instance_by_id(instance_id)
  end

  return sorted[instance_id]
end

--- Finds an item by a loose query.
-- A number is treated as an instance id. A string is compared against the template ids
-- and matched as a Lua pattern against the template names and print names.
-- @param name [String/Number item id or (part of) item name, or an instance id]
-- @return [Item first matching template, or the instance for a number; nil if not found]
function Item.find(name)
  if isnumber(name) then
    return Item.find_instance_by_id(name)
  end

  if stored[name] then
    return stored[name]
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

--- Generates the next unused item instance id.
-- @return [Number]
function Item.generate_id()
  instances.count = instances.count or 0
  instances.count = instances.count + 1

  return instances.count
end

--- Creates a new instance of an item template.
-- On the server it also runs the 'OnItemCreated' hook, saves the items
-- and sends the new instance to all clients.
-- ```
-- local item_obj = Item.create('test_item', { name = 'Some Item' })
--
-- if item_obj then
--   Item.spawn(actor:GetEyeTraceNoCursor().HitPos, nil, item_obj)
-- end
-- ```
-- @param id [String item id of the template]
-- @param data=nil [Map fields to override on the new instance]
-- @param forced_id=nil [Number instance id to use instead of generating a new one]
-- @return [Item the new instance, or nil if there is no such template]
function Item.create(id, data, forced_id)
  local item_obj = Item.find_by_id(id)

  if item_obj then
    local item_id = forced_id or Item.generate_id()

    instances[id] = instances[id] or {}
    instances[id][item_id] = table.Copy(item_obj)

    if istable(data) then
      table.safe_merge(instances[id][item_id], data)
    end

    instances[id][item_id].instance_id = item_id

    if SERVER then
      --- Called on the server when `Item.create` has created a new item instance.
      -- At this point the instance has its instance id and the overridden fields, but it
      -- has not been saved or sent to the clients yet and it is not in any inventory.
      -- The Items plugin uses the hook to call the `on_created` callback of the item.
      -- It is not run for the instances that `Item.load` restores.
      -- @param item_obj [Item The new item instance]
      hook.Run('OnItemCreated', instances[id][item_id])

      Item.async_save()
      Cable.send(nil, 'fl_items_new_instance', id, (data or 1), item_id)
    end

    return instances[id][item_id]
  end
end

--- Removes an item instance along with its entity in the world, if it has one.
-- Does not take the item out of the inventory that holds it. On the server it also saves
-- the items and tells every client to remove its copy of the instance.
-- @param instance_id [Number/Item instance id, or the item instance itself]
function Item.remove(instance_id)
  local item_obj = (istable(instance_id) and instance_id) or Item.find_instance_by_id(instance_id)

  if item_obj and Item.is_instance(item_obj) then
    if IsValid(item_obj.entity) then
      item_obj.entity:Remove()
    end

    if instances[item_obj.id] then
      instances[item_obj.id][item_obj.instance_id] = nil
    end

    sorted[item_obj.instance_id] = nil

    if SERVER then
      expected_drops[item_obj.instance_id] = nil

      Item.async_save()
      Cable.send(nil, 'fl_items_remove', item_obj.instance_id)
    end

    Flux.dev_print('Removed item instance ID: '..item_obj.instance_id)
  end
end

--- Checks whether the table is an item instance rather than an item template.
-- @param item_obj [Item]
-- @return [Boolean nil if the argument is not a table]
function Item.is_instance(item_obj)
  if !istable(item_obj) then return end

  return (item_obj.instance_id or ITEM_TEMPLATE) > ITEM_TEMPLATE
end

--- Applies the bodygroups of an item's model to an entity, the way the item entity gets
-- them. Bodygroups that are given by name and that the model of the entity does not have
-- are skipped, so the model has to be set first.
-- @param entity [Entity the entity to set the bodygroups on]
-- @param item_obj [Item the item whose model bodygroups to apply]
-- @see [ItemBase#get_model_bodygroups]
function Item.apply_bodygroups(entity, item_obj)
  local bodygroups = item_obj:get_model_bodygroups()

  if !istable(bodygroups) then return end

  for k, v in pairs(bodygroups) do
    local index = tonumber(k) or entity:FindBodygroupByName(k)

    if index and index >= 0 then
      entity:SetBodygroup(index, tonumber(v) or 0)
    end
  end
end

--- Includes every item file of a folder through the 'item' pipeline, registering the items.
-- @param directory [String path to the folder, e.g. plugin:get_folder()..'/items/']
function Item.include_items(directory)
  Pipeline.include_folder('item', directory)
end

local item_categories = {}

--- Sets the icon that represents an item category in the spawn menu.
-- @param category [String category id, e.g. 'item.category.weapon']
-- @param icon [String path to the icon, e.g. 'icon16/gun.png']
function Item.set_category_icon(category, icon)
  item_categories[category] = icon
end

--- Returns the icon of an item category.
-- @param category [String category id]
-- @return [String path to the icon; 'icon16/bricks.png' if the category has none]
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
  --- Loads the item instances and the item entities saved for the current map,
  -- and spawns the entities back into the world. Server-side only.
  function Item.load()
    local loaded = Data.load_schema('items/instances', {})

    if loaded and !table.IsEmpty(loaded) then
      -- Returns functions to the instances table after loading.
      for id, instance_table in pairs(loaded) do
        local item_obj = Item.find_by_id(id)

        if item_obj then
          for k, v in pairs(instance_table) do
            local new_item = table.Copy(item_obj)

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
            Item.spawn(v.position, v.angles, instances[id][k], v.dropped_by or false)
          else
            loaded[id][k] = nil
          end
        end
      end

      entities = loaded
      Item.entities = loaded
    end
  end

  --- Saves all the item instances to the schema data of the current map. Server-side only.
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

  --- Saves positions and angles of all the item entities in the world, along with the
  -- characters that dropped them. Entities that are being removed are left out.
  -- Server-side only.
  function Item.save_entities()
    local item_ents = ents.FindByClass('fl_item')

    entities = {}

    for k, v in ipairs(item_ents) do
      if IsValid(v) and !v:IsMarkedForDeletion() and v.item then
        entities[v.item.id] = entities[v.item.id] or {}

        entities[v.item.id][v.item.instance_id] = {
          position = v:GetPos(),
          angles = v:GetAngles(),
          dropped_by = v.dropped_by
        }
      end
    end

    Data.save_schema('items/entities', entities)
  end

  --- Saves both the item instances and the item entities. Server-side only.
  function Item.save_all()
    Item.save_instances()
    Item.save_entities()
  end

  --- Runs Item.save_all inside of a coroutine. Server-side only.
  function Item.async_save()
    local handle = coroutine.create(Item.save_all)
    coroutine.resume(handle)
  end

  --- Runs Item.save_instances inside of a coroutine. Server-side only.
  function Item.async_save_instances()
    local handle = coroutine.create(Item.save_instances)
    coroutine.resume(handle)
  end

  --- Runs Item.save_entities inside of a coroutine. Server-side only.
  function Item.async_save_entities()
    local handle = coroutine.create(Item.save_entities)
    coroutine.resume(handle)
  end

  --- Sends the custom data of an item instance to the client. Server-side only.
  -- Does nothing if the item is a template.
  -- @param target [Player/List<Player>/Nil who to send to; nil sends to everyone]
  -- @param item_obj [Item]
  function Item.network_item_data(target, item_obj)
    if Item.is_instance(item_obj) then
      Cable.send(target, 'fl_items_data', item_obj.id, item_obj.instance_id, item_obj.data)
    end
  end

  --- Sends the saveable fields of an item instance to the client,
  -- which builds its own copy of the instance out of them. Server-side only.
  -- @param target [Player/List<Player>/Nil who to send to; nil sends to everyone]
  -- @param instance_id [Number]
  function Item.network_item(target, instance_id)
    Cable.send(target, 'fl_items_network', instance_id, Item.to_saveable(Item.find_instance_by_id(instance_id)))
  end

  --- Tells the client which item instance an item entity represents. Server-side only.
  -- @param target [Player/List<Player>/Nil who to send to; nil sends to everyone]
  -- @param ent [Entity the fl_item entity]
  function Item.network_entity_data(target, ent)
    if IsValid(ent) then
      Cable.send(target, 'fl_items_ent_data', ent:EntIndex(), ent.item.id, ent.item.instance_id)
    end
  end

  --- Sends info about items in the world to the player,
  -- then runs the 'OnItemDataReceived' hook on their client. Server-side only.
  -- @param target [Player]
  function Item.send_to_player(target)
    local item_ents = ents.FindByClass('fl_item')

    for k, v in ipairs(item_ents) do
      if v.item then
        Item.network_item(target, v.item.instance_id)
      end
    end

    hook.run_client(target, 'OnItemDataReceived')
  end

  --- Names the player who is about to drop an item, for code that spawns the item without
  -- passing a dropper to Item.spawn. The next Item.spawn of the item uses that player,
  -- provided that it happens within the same tick. Server-side only.
  -- The Items plugin calls it from its 'CanPlayerDropItem' handler, which is how the items
  -- that the Inventory plugin drops get their dropper.
  -- @param item_obj [Item the item instance that is about to be dropped]
  -- @param actor [Player the player dropping it]
  -- @see [Item.spawn]
  function Item.expect_drop(item_obj, actor)
    if !Item.is_instance(item_obj) then return end

    expected_drops[item_obj.instance_id] = { actor = actor, time = CurTime() }
  end

  --- Returns the player that Item.expect_drop has named as the dropper of an item during
  -- the current tick, and forgets them. Server-side only.
  -- @param item_obj [Item]
  -- @return [Player the dropper, or nil if nobody is expected to drop the item right now]
  function Item.take_expected_dropper(item_obj)
    local expected = expected_drops[item_obj.instance_id]

    expected_drops[item_obj.instance_id] = nil

    if expected and expected.time == CurTime() and IsValid(expected.actor) then
      return expected.actor
    end
  end

  --- Spawns an item instance in the world as an fl_item entity. Server-side only.
  -- The item is sent to all clients and the item entities are saved afterward. The entity
  -- remembers the character of the dropper, and the on_entity_spawned callback of the item
  -- is called once the entity is in the world.
  -- ```
  -- local item_obj = Item.create('test_item')
  -- local trace = actor:GetEyeTraceNoCursor()
  -- local ent = Item.spawn(trace.HitPos, Angle(0, 0, 0), item_obj)
  -- ```
  -- @param position [Vector where to put the item; it is raised by the height of its bounds]
  -- @param angles=nil [Angle]
  -- @param item_obj [Item item instance; templates cannot be spawned]
  -- @param dropper=nil [Player/Map/Boolean the player who drops the item, or a table with
  --   the character_id and steam_id fields of an earlier drop, or false if nobody does;
  --   when nil, the player named by Item.expect_drop is used, if there is one]
  -- @return [Entity the item entity, Item the spawned item; nothing if the arguments are invalid]
  -- @see [Item.expect_drop]
  function Item.spawn(position, angles, item_obj, dropper)
    if !position or !istable(item_obj) then
      error_with_traceback('No position or item table is not a table!')
      return
    end

    if !Item.is_instance(item_obj) then
      error_with_traceback('Cannot spawn a non-instantiated item!')
      return
    end

    local ent = ents.Create('fl_item')

    ent:set_item(item_obj)

    local mins, maxs = ent:GetCollisionBounds()

    ent:SetPos(position + Vector(0, 0, maxs.z))

    if angles then
      ent:SetAngles(angles)
    end

    ent:Spawn()

    if dropper == nil then
      dropper = Item.take_expected_dropper(item_obj)
    else
      expected_drops[item_obj.instance_id] = nil
    end

    ent:set_dropper(dropper)

    item_obj:set_entity(ent)
    Item.network_item(nil, item_obj.instance_id)

    entities[item_obj.id] = entities[item_obj.id] or {}
    entities[item_obj.id][item_obj.instance_id] = entities[item_obj.id][item_obj.instance_id] or {}
    entities[item_obj.id][item_obj.instance_id] = {
      position = position,
      angles = angles,
      dropped_by = ent.dropped_by
    }

    Item.async_save_entities()

    if item_obj.on_entity_spawned then
      item_obj:on_entity_spawned(ent)
    end

    return ent, item_obj
  end

  Cable.receive('fl_items_data_request', function(actor, ent_index)
    local ent = Entity(ent_index)

    if IsValid(ent) then
      Item.network_entity_data(actor, ent)
    end
  end)
else
  Cable.receive('fl_items_data', function(id, instance_id, data)
    if istable(instances[id][instance_id]) then
      instances[id][instance_id].data = data
    end
  end)

  Cable.receive('fl_items_network', function(instance_id, item_obj)
    if item_obj and stored[item_obj.id] then
      local new_table = table.Copy(stored[item_obj.id])
      table.safe_merge(new_table, item_obj)

      instances[new_table.id][instance_id] = new_table
    else
      print('Failed to receive item instance #'..(instance_id or '')..', please report that.')
    end
  end)

  Cable.receive('fl_items_ent_data', function(ent_index, id, instance_id)
    local ent = Entity(ent_index)

    if IsValid(ent) then
      local item_obj = instances[id][instance_id]

      if item_obj == nil then
        return Cable.send('fl_items_data_request', ent_index)
      end

      -- The client has to know this shit too I guess?
      ent:SetModel(item_obj:get_model())
      ent:SetSkin(item_obj.skin)
      ent:SetColor(item_obj:get_color())

      Item.apply_bodygroups(ent, item_obj)

      -- Restore the item's functions. For some weird reason they aren't properly initialized.
      table.safe_merge(ent, scripted_ents.Get('fl_item'))

      ent.item = item_obj
    end
  end)

  Cable.receive('fl_items_new_instance', function(id, data, item_id)
    Item.create(id, data, item_id)
  end)

  Cable.receive('fl_items_remove', function(instance_id)
    Item.remove(instance_id)
  end)
end

Pipeline.register('item', function(id, file_name, pipe)
  ITEM = ItemBase.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then ITEM = nil return end

  ITEM:register() ITEM = nil
end)
