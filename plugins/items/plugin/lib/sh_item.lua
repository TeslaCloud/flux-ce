--- The Item library keeps track of item templates and item instances.
-- Templates are the item classes registered from item files. The `item` pipeline, defined
-- at the end of this file, creates an `ItemBase` object for every file, runs the file with
-- that object as `ITEM` and passes it to `Item.register`. `Item.create` makes an instance
-- out of a template, with an instance id of its own, and `Item.spawn` puts an instance
-- into the world as an `fl_item` entity.
--
-- An instance only holds what is its own: its instance id, its custom data (`data`), the
-- fields that `Item.create` was told to override, and where it is. Everything else it
-- reads from its template through its metatable, so it costs little memory. When an item
-- file is registered again, after a Lua refresh for instance, the loaded instances of the
-- item read from the new template.
--
-- Instances live in the `items` table of the database, one row each, and the server keeps
-- in memory only those that are in use: the items of the characters that players have
-- loaded, and the items of the current map, in containers or lying in the world. How they
-- are loaded and written back is described in the Items plugin's `lib/sv_storage.lua`.
-- `Item.remove` deletes an instance for good.
--
-- Clients only get the instances they need: those in the inventories they receive, and
-- those lying in the world near them, which a client asks for once the entity of the item
-- reaches it. The server remembers which players know an instance, so that changes and
-- the removal of the instance reach exactly them (`Item.network_item`,
-- `Item.network_item_data`). Plugins can add fields to what is sent through the
-- `PreItemNetwork` hook.
--
-- An item entity remembers the character that dropped it: `Item.spawn` takes the dropper
-- as its last argument, which the Items plugin passes whenever a player drops an item
-- from an inventory.

local pairs = pairs
local istable = istable

mod 'Item'

local stored = Item.stored or {}
local instances = Item.instances or {}
local instance_metas = setmetatable({}, { __mode = 'k' })

Item.stored = stored
Item.instances = instances

--- Returns all the registered item templates.
-- @return [Map item templates, keyed by item id]
function Item.all()
  return stored
end

--- Returns the item instances that are loaded. On the server those are the instances that
-- are in use, see the top of this file; on a client those that the server has sent.
-- @return [Map item instances, keyed by instance id]
function Item.get_instances()
  return instances
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
  data.model_bodygroups = data.model_bodygroups or nil
  data.icon_data = data.icon_data or nil
  data.icon_material = data.icon_material or nil

  local previous = stored[id]
  local meta = previous and previous != data and instance_metas[previous]

  if meta then
    meta.__index = data
    meta.__tostring = data.__tostring
    instance_metas[previous] = nil
    instance_metas[data] = meta
  end

  stored[id] = data
end

local function get_instance_meta(template)
  local meta = instance_metas[template]

  if !meta then
    meta = {
      __index = template,
      __tostring = template.__tostring
    }

    instance_metas[template] = meta
  end

  return meta
end

--- Builds an instance of a template without registering it anywhere. The instance gets
-- its own copy of the default custom data of the template, with `data` merged on top.
-- Fields of `overrides` are set on the instance and kept in its `overrides` field, so that
-- they are saved with it; a `data` field among them is merged into the custom data instead.
-- `Item.create` and the database loader build instances with it.
-- @param template [Item the item template]
-- @param instance_id [Number]
-- @param overrides=nil [Map fields to override on the instance]
-- @param data=nil [Map custom data of the instance]
-- @return [Item the new instance]
function Item.instantiate(template, instance_id, overrides, data)
  local item_obj = setmetatable({}, get_instance_meta(template))
  local custom_data = istable(template.data) and table.Copy(template.data) or {}

  if istable(overrides) then
    local own = {}

    for key, value in pairs(overrides) do
      if key == 'data' and istable(value) then
        table.Merge(custom_data, value)
      elseif key != 'instance_id' and key != 'id' then
        own[key] = value
        item_obj[key] = value
      end
    end

    if next(own) != nil then
      item_obj.overrides = own
    end
  end

  if istable(data) then
    table.Merge(custom_data, data)
  end

  item_obj.data = custom_data
  item_obj.instance_id = instance_id

  return item_obj
end

--- Builds a plain table with what a client needs to know about an item instance: its
-- template, its instance id, its custom data and its overridden fields.
-- Runs the 'PreItemNetwork' hook so that plugins can add fields of their own.
-- @param item_obj [Item]
-- @return [Map networkable fields, or nil if no item was given]
function Item.to_networkable(item_obj)
  if !item_obj then return end

  local fields = {}

  if istable(item_obj.overrides) then
    for key, value in pairs(item_obj.overrides) do
      fields[key] = value
    end
  end

  fields.id = item_obj.id
  fields.instance_id = item_obj.instance_id
  fields.data = item_obj.data

  --- Lets plugins add fields to what a client is sent about an item instance. Called by
  -- `Item.to_networkable` on the server whenever an instance is sent to a client. The
  -- client builds its copy of the instance out of the template and these fields.
  -- Handlers write their fields into `fields`; the Items plugin adds the position of
  -- the item in its inventory.
  -- @param item_obj [Item The item that is being sent]
  -- @param fields [Map The fields that are going to be sent, to be modified in place]
  hook.Run('PreItemNetwork', item_obj, fields)

  return fields
end

--- Finds an item template by its id.
-- @param id [String item id]
-- @return [Item the template, or nil if not found]
function Item.find_by_id(id)
  local item_obj = stored[id]

  if item_obj then
    return item_obj
  end

  for item_id, template in pairs(stored) do
    if item_id == id or template.id == id then
      return template
    end
  end
end

--- Finds all the loaded instances of a certain item template.
-- @param id [String item id]
-- @return [Map item instances keyed by instance id, or nil if there is no such template]
function Item.find_all_instances(id)
  if !stored[id] then return end

  local found = {}

  for instance_id, item_obj in pairs(instances) do
    if item_obj.id == id then
      found[instance_id] = item_obj
    end
  end

  return found
end

--- Finds a loaded item instance by its instance id.
-- @param instance_id [Number]
-- @return [Item the instance, or nil if not found]
function Item.find_instance_by_id(instance_id)
  if instance_id == nil then return end

  return instances[instance_id]
end

--- Finds a loaded item instance by its instance id. The same as Item.find_instance_by_id.
-- @param instance_id [Number]
-- @return [Item the instance, or nil if not found]
function Item.find_by_instance_id(instance_id)
  return Item.find_instance_by_id(instance_id)
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

  for _, template in pairs(stored) do
    if template.id and template.name and template.print_name then
      if template.id == name or template.name:find(name) or template.print_name:find(name) then
        return template
      end

      if CLIENT then
        if template.print_name:find(name) then
          return template
        end
      end
    end
  end
end

--- Removes an item instance along with its entity in the world, if it has one, and along
-- with everything inside of it, if it is a container item. Does not take the item out of
-- the inventory that holds it. On the server it also deletes the instance from the
-- database and tells the clients that know the instance to forget it; the client only
-- forgets the instance, since the entity is removed by the server.
-- @param instance_id [Number/Item instance id, or the item instance itself]
function Item.remove(instance_id)
  local item_obj = (istable(instance_id) and instance_id) or Item.find_instance_by_id(instance_id)

  if !item_obj or !Item.is_instance(item_obj) then return end

  if SERVER then
    if IsValid(item_obj.entity) then
      item_obj.entity:Remove()
    end

    local inventory = item_obj.inventory

    if inventory and inventory.get_items_ids then
      for _, content_id in ipairs(inventory:get_items_ids()) do
        if content_id != item_obj.instance_id then
          Item.remove(content_id)
        end
      end
    end

    Item.forget(item_obj, true)
  elseif instances[item_obj.instance_id] == item_obj then
    instances[item_obj.instance_id] = nil
  end

  Flux.dev_print('Removed item instance ID: '..item_obj.instance_id)
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

  for bodygroup, value in pairs(bodygroups) do
    local index = tonumber(bodygroup) or entity:FindBodygroupByName(bodygroup)

    if index and index >= 0 then
      entity:SetBodygroup(index, tonumber(value) or 0)
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
  --- Creates a new instance of an item template, with a new instance id. Server-side only.
  -- Runs the 'OnItemCreated' hook. The instance is written to the database once it is
  -- somewhere: in an inventory that is saved, or in the world. An instance that is still
  -- nowhere when the changes are written is removed, so put it where it belongs right away.
  -- ```
  -- local item_obj = Item.create('test_item', { name = 'Some Item' })
  --
  -- if item_obj then
  --   Item.spawn(actor:GetEyeTraceNoCursor().HitPos, nil, item_obj)
  -- end
  -- ```
  -- @param id [String item id of the template]
  -- @param data=nil [Map fields to override on the new instance; a data field is merged
  --   into its custom data. The overridden fields are saved with the instance]
  -- @return [Item the new instance, or nil if there is no such template or no instance id
  --   could be reserved]
  function Item.create(id, data)
    local template = Item.find_by_id(id)

    if !template then return end

    local instance_id = Item.generate_id()

    if !instance_id then return end

    local new_item = Item.instantiate(template, instance_id, istable(data) and data or nil)

    instances[instance_id] = new_item

    --- Called on the server when `Item.create` has created a new item instance.
    -- At this point the instance has its instance id and the overridden fields, but it
    -- has not been saved or sent to any client yet and it is not in any inventory.
    -- The Items plugin uses the hook to call the `on_created` callback of the item.
    -- It is not run for the instances that are loaded from the database.
    -- @param item_obj [Item The new item instance]
    hook.Run('OnItemCreated', new_item)

    Item.mark_dirty(new_item)

    return new_item
  end

  --- Returns the players that have been sent an item instance and have not been told to
  -- forget it yet. Server-side only.
  -- @param item_obj [Item]
  -- @return [List<Player> connected players]
  function Item.get_receivers(item_obj)
    local list = {}
    local receivers = istable(item_obj) and item_obj.receivers

    if receivers then
      for receiver in pairs(receivers) do
        if IsValid(receiver) then
          list[#list + 1] = receiver
        else
          receivers[receiver] = nil
        end
      end
    end

    return list
  end

  local function add_receivers(target, item_obj)
    local receivers = item_obj.receivers

    if !receivers then
      receivers = {}
      item_obj.receivers = receivers
    end

    local targets = istable(target) and target or { target }

    for _, receiver in ipairs(targets) do
      if IsValid(receiver) and receiver:IsPlayer() then
        receivers[receiver] = true

        local known = receiver.known_items or {}

        known[item_obj.instance_id] = true
        receiver.known_items = known
      end
    end
  end

  --- Tells the clients that know an item instance to forget it, and forgets that they
  -- know it. Server-side only.
  -- @param item_obj [Item]
  function Item.network_forget(item_obj)
    local receivers = Item.get_receivers(item_obj)

    if #receivers > 0 then
      Cable.send(receivers, 'fl_items_remove', item_obj.instance_id)
    end

    for _, receiver in ipairs(receivers) do
      if receiver.known_items then
        receiver.known_items[item_obj.instance_id] = nil
      end
    end

    item_obj.receivers = nil
  end

  --- Sends the custom data of an item instance to clients. Server-side only.
  -- Does nothing if the item is a template.
  -- @param target [Player/List<Player>/Nil who to send to; nil sends to the players that
  --   know the instance]
  -- @param item_obj [Item]
  function Item.network_item_data(target, item_obj)
    if !Item.is_instance(item_obj) then return end

    target = target or Item.get_receivers(item_obj)

    if istable(target) and #target == 0 then return end

    Cable.send(target, 'fl_items_data', item_obj.instance_id, item_obj.data)
  end

  --- Sends what a client needs to know about an item instance to clients, which build
  -- their own copies of the instance out of it, and remembers that they know the instance.
  -- Server-side only.
  -- @param target [Player/List<Player>/Nil who to send to; nil sends to the players that
  --   know the instance]
  -- @param instance_id [Number]
  function Item.network_item(target, instance_id)
    local item_obj = Item.find_instance_by_id(instance_id)

    if !item_obj then return end

    target = target or Item.get_receivers(item_obj)

    if istable(target) and #target == 0 then return end

    add_receivers(target, item_obj)

    Cable.send(target, 'fl_items_network', instance_id, Item.to_networkable(item_obj))
  end

  --- Tells clients which item instance an item entity represents. Server-side only.
  -- @param target [Player/List<Player>/Nil who to send to; nil sends to the players that
  --   know the instance of the entity]
  -- @param ent [Entity the fl_item entity]
  function Item.network_entity_data(target, ent)
    if !IsValid(ent) or !ent.item then return end

    target = target or Item.get_receivers(ent.item)

    if istable(target) and #target == 0 then return end

    Cable.send(target, 'fl_items_ent_data', ent:EntIndex(), ent.item.instance_id)
  end

  --- Sends an item entity and its item instance to a player. Server-side only.
  -- @param target [Player]
  -- @param ent [Entity the fl_item entity]
  function Item.send_entity(target, ent)
    if !IsValid(ent) or !ent.item then return end

    Item.network_item(target, ent.item.instance_id)
    Item.network_entity_data(target, ent)
  end

  --- Spawns an item instance in the world as an fl_item entity. Server-side only.
  -- The item stops being held by the inventory it was saved in, so take it out of its
  -- inventory first. The entity remembers the character of the dropper, and the
  -- on_entity_spawned callback of the item is called once the entity is in the world.
  -- Clients ask for the item once the entity reaches them.
  -- ```
  -- local item_obj = Item.create('test_item')
  -- local trace = actor:GetEyeTraceNoCursor()
  -- local ent = Item.spawn(trace.HitPos, Angle(0, 0, 0), item_obj)
  -- ```
  -- @param position [Vector where to put the item; it is raised by the height of its bounds
  --   unless `exact` is set]
  -- @param angles=nil [Angle]
  -- @param item_obj [Item item instance; templates cannot be spawned]
  -- @param dropper=nil [Player/Map/Boolean the player who drops the item, or a table with
  --   the character_id and steam_id fields of an earlier drop; nil or false if nobody does]
  -- @param exact=false [Boolean put the entity exactly at the position, without raising it]
  -- @return [Entity the item entity, Item the spawned item; nothing if the arguments are invalid]
  function Item.spawn(position, angles, item_obj, dropper, exact)
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

    if exact then
      ent:SetPos(position)
    else
      local _mins, maxs = ent:GetCollisionBounds()

      ent:SetPos(position + Vector(0, 0, maxs.z))
    end

    if angles then
      ent:SetAngles(angles)
    end

    ent:Spawn()
    ent:set_dropper(dropper)

    item_obj:set_entity(ent)
    Item.set_holder(item_obj)

    if item_obj.on_entity_spawned then
      item_obj:on_entity_spawned(ent)
    end

    return ent, item_obj
  end
end

Pipeline.register('item', function(id, file_name, _pipe)
  ITEM = ItemBase.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then ITEM = nil return end

  ITEM:register() ITEM = nil
end)
