--- Containers turns props with certain models into storage for items.
-- A model is registered with `Container:register_prop` together with the size of its
-- inventory, its name, its description and its sounds; common furniture, crates and boxes of
-- Half-Life 2 are registered here. A prop that is spawned with such a model becomes
-- persistent, shows its name when it is looked at and can be opened from its interaction menu
-- by a player within reach of it. Its inventory is created the first time it is opened and
-- is closed for a player who moves out of reach.
--
-- Staff can give a container a name of its own, a message that is shown to whoever opens it
-- and a password that has to be entered before it opens, and fill it with random items.
-- All of this is done with the Container Tool, which needs the `manage_containers`
-- permission (and `fill_containers` to fill), or from code with
-- `Container:set_container_name`, `Container:set_container_message`,
-- `Container:set_container_password` and `Container:fill`. The name, the message and the
-- password are kept on the prop in its `container_name`, `container_message` and
-- `container_password` fields, so they are saved with it the same way its items are. A
-- wrong password makes the player wait for `container_password_delay` seconds before the
-- next attempt.
--
-- Random items are picked among all registered items but the bases and those that set
-- `ITEM.lootable = false`, optionally from one item category.
--
-- When a container prop is removed, its items are destroyed with it, or dropped on the
-- ground if the `container_spill_items` config is on.
--
-- Hooks: `PlayerCanOpenContainer` and `ShouldAskContainerPassword` decide who opens a
-- container and who has to enter its password, `PlayerEnteredContainerPassword` tells about
-- every entered password, `PreContainerOpen` is run before a container is shown to a player
-- and `OnContainerRemoved` after the items of a removed container have been dealt with.

PLUGIN:set_global('Container')

local stored = Container.stored or {}
Container.stored = stored

do
  --- Makes props with the specified model(s) work as containers.
  -- ```
  -- Container:register_prop('models/props_c17/FurnitureDrawer002a.mdl', {
  --   name = 'container.small_drawer.title',
  --   desc = 'container.small_drawer.desc',
  --   w = 2,
  --   h = 1,
  --   open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  --   close_sound = 'physics/wood/wood_box_impact_hard6.wav'
  -- })
  -- ```
  -- @param model [String/List<String> path to the model, or a list of them]
  -- @param data [Map container data: name and desc (language phrases), w and h (size of the
  --   inventory in slots), and optionally open_sound and close_sound]
  function Container:register_prop(model, data)
    if istable(model) then
      for k, v in pairs(model) do
        stored[v:lower()] = data
      end
    else
      stored[model:lower()] = data
    end
  end

  --- Returns all the registered containers.
  -- @return [Map container data, keyed by the lowercase path to the model]
  function Container:all()
    return stored
  end

  --- Finds the container data that is registered for the model.
  -- @param model [String path to the model; case-insensitive]
  -- @return [Map container data, or nil if the model is not a container]
  function Container:find(model)
    return stored[model:lower()]
  end

  --- Returns the container data of an entity, if the entity is a container: a valid
  -- physics prop with a registered model.
  -- @param entity [Entity]
  -- @return [Map container data, or nil if the entity is not a container]
  function Container:get_container_data(entity)
    if !isentity(entity) or !IsValid(entity) or entity:GetClass() != 'prop_physics' then return end

    local model = entity:GetModel()

    if isstring(model) then
      return stored[model:lower()]
    end
  end

  --- Checks whether an entity is a container: a valid physics prop with a registered model.
  -- @param entity [Entity]
  -- @return [Boolean]
  function Container:is_container(entity)
    return self:get_container_data(entity) != nil
  end
end

--- Returns the name of a container: the one it was given with
-- `Container:set_container_name`, or else the name that is registered for its model.
-- ```
-- local name, is_custom = Container:get_container_name(entity)
-- local text = is_custom and name or t(name)
-- ```
-- @param entity [Entity the container prop]
-- @return [String the custom name as it was entered, or the language phrase of the default
--   name; nil if the model of the entity is not registered, Boolean true if the name is a
--   custom one]
function Container:get_container_name(entity)
  local custom_name = SERVER and entity.container_name or entity:get_nv('fl_container_name')

  if isstring(custom_name) and custom_name != '' then
    return custom_name, true
  end

  local model = entity:GetModel()
  local container_data = isstring(model) and self:find(model)

  return container_data and container_data.name or nil, false
end

--- Checks whether a password has to be entered to open a container. The password itself
-- is only known to the server.
-- @param entity [Entity the container prop]
-- @return [Boolean]
function Container:has_container_password(entity)
  if SERVER then
    return entity.container_password != nil
  end

  return entity:get_nv('fl_container_locked', false) == true
end

--- Returns the item templates that containers can be filled with: every registered item
-- except for the bases and the items that set `lootable` to false.
-- ```
-- -- In an item file: keeps the item out of the randomly filled containers.
-- ITEM.lootable = false
-- ```
-- @param category=nil [String item category to pick from, e.g.
--   'item.category.consumables'; items of all categories if nil]
-- @return [List<Item> item templates]
function Container:get_loot_items(category)
  local items = {}

  for id, item_table in pairs(Item.all()) do
    if !item_table.is_base and item_table.lootable != false
    and (!category or item_table.category == category) then
      table.insert(items, item_table)
    end
  end

  return items
end

--- Returns the categories of the items that containers can be filled with.
-- @return [List<String> item category IDs in alphabetical order]
function Container:get_loot_categories()
  local categories = {}
  local seen = {}

  for k, item_table in ipairs(self:get_loot_items()) do
    local category = item_table.category

    if isstring(category) and !seen[category] then
      seen[category] = true

      table.insert(categories, category)
    end
  end

  table.sort(categories)

  return categories
end

--- Registers the 'manage_containers' and 'fill_containers' level design permissions.
function Container:RegisterPermissions()
  Bolt:register_permission(
    'manage_containers',
    'Manage containers',
    'Grants access to set the names, messages and passwords of containers.',
    'permission.categories.level_design',
    'assistant'
  )
  Bolt:register_permission(
    'fill_containers',
    'Fill containers',
    'Grants access to fill containers with random items.',
    'permission.categories.level_design',
    'moderator'
  )
end

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

Container:register_prop({
  'models/props_junk/cardboard_box001a.mdl',
  'models/props_junk/cardboard_box001b.mdl',
  'models/props_junk/cardboard_box002a.mdl',
  'models/props_junk/cardboard_box002b.mdl'
},
{
  name = 'container.box.title',
  desc = 'container.box.desc',
  w = 4,
  h = 3,
  open_sound = 'physics/cardboard/cardboard_box_impact_soft5.wav',
  close_sound = 'physics/cardboard/cardboard_box_impact_soft7.wav'
})

Container:register_prop('models/props_c17/FurnitureCupboard001a.mdl', {
  name = 'container.cupboard.title',
  desc = 'container.cupboard.desc',
  w = 4,
  h = 3,
  open_sound = 'doors/door1_move.wav',
  close_sound = 'doors/door1_stop.wav'
})

Container:register_prop('models/props_c17/FurnitureDrawer001a.mdl', {
  name = 'container.drawer.title',
  desc = 'container.drawer.desc',
  w = 5,
  h = 4,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop('models/props_c17/FurnitureDrawer002a.mdl', {
  name = 'container.small_drawer.title',
  desc = 'container.small_drawer.desc',
  w = 2,
  h = 1,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop('models/props_c17/FurnitureDrawer003a.mdl', {
  name = 'container.tall_drawer.title',
  desc = 'container.tall_drawer.desc',
  w = 1,
  h = 10,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop('models/props_c17/FurnitureDresser001a.mdl', {
  name = 'container.dresser.title',
  desc = 'container.dresser.desc',
  w = 4,
  h = 6,
  open_sound = 'doors/door1_move.wav',
  close_sound = 'doors/door1_stop.wav'
})

Container:register_prop('models/props_c17/FurnitureFridge001a.mdl', {
  name = 'container.fridge.title',
  desc = 'container.fridge.desc',
  w = 4,
  h = 5,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_c17/Lockers001a.mdl', {
  name = 'container.lockers.title',
  desc = 'container.lockers.desc',
  w = 5,
  h = 4,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_c17/oildrum001.mdl', {
  name = 'container.barrel.title',
  desc = 'container.barrel.desc',
  w = 3,
  h = 5,
  open_sound = 'physics/metal/metal_barrel_impact_soft3.wav',
  close_sound = 'physics/metal/metal_barrel_impact_soft4.wav'
})

Container:register_prop({
  'models/props_combine/breendesk.mdl',
  'models/props_interiors/Furniture_Desk01a.mdl'
},
{
  name = 'container.desk.title',
  desc = 'container.desk.desc',
  w = 5,
  h = 3,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop({
  'models/props_junk/cardboard_box003a.mdl',
  'models/props_junk/cardboard_box003b.mdl'
},
{
  name = 'container.medium_box.title',
  desc = 'container.medium_box.desc',
  w = 3,
  h = 2,
  open_sound = 'physics/cardboard/cardboard_box_impact_soft5.wav',
  close_sound = 'physics/cardboard/cardboard_box_impact_soft7.wav'
})

Container:register_prop('models/props_junk/cardboard_box004a.mdl', {
  name = 'container.small_box.title',
  desc = 'container.small_box.desc',
  w = 1,
  h = 1,
  open_sound = 'physics/cardboard/cardboard_box_impact_soft5.wav',
  close_sound = 'physics/cardboard/cardboard_box_impact_soft7.wav'
})

Container:register_prop('models/props_junk/TrashBin01a.mdl', {
  name = 'container.trash_bin.title',
  desc = 'container.trash_bin.desc',
  w = 3,
  h = 5,
  open_sound = 'physics/plastic/plastic_box_impact_soft3.wav',
  close_sound = 'physics/plastic/plastic_box_impact_soft1.wav'
})

Container:register_prop('models/props_junk/TrashDumpster01a.mdl', {
  name = 'container.dumpster.title',
  desc = 'container.dumpster.desc',
  w = 6,
  h = 5,
  open_sound = 'physics/metal/metal_solid_strain1.wav',
  close_sound = 'physics/metal/metal_sheet_impact_hard7.wav'
})

Container:register_prop({
  'models/props_junk/wood_crate001a.mdl',
  'models/props_junk/wood_crate001a_damaged.mdl'
},
{
  name = 'container.wooden_crate.title',
  desc = 'container.wooden_crate.desc',
  w = 5,
  h = 5,
  open_sound = 'physics/wood/wood_box_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard5.wav'
})

Container:register_prop('models/props_junk/wood_crate002a.mdl', {
  name = 'container.big_wooden_crate.title',
  desc = 'container.big_wooden_crate.desc',
  w = 8,
  h = 5,
  open_sound = 'physics/wood/wood_box_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard5.wav'
})

Container:register_prop({
  'models/props_lab/filecabinet02.mdl',
  'models/props_wasteland/controlroom_filecabinet001a.mdl'
},
{
  name = 'container.file_cabinet.title',
  desc = 'container.file_cabinet.desc',
  w = 2,
  h = 3,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_wasteland/controlroom_filecabinet002a.mdl', {
  name = 'container.tall_file_cabinet.title',
  desc = 'container.tall_file_cabinet.desc',
  w = 2,
  h = 6,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop({
  'models/props_wasteland/controlroom_storagecloset001a.mdl',
  'models/props_wasteland/controlroom_storagecloset001b.mdl'
},
{
  name = 'container.storage_closet.title',
  desc = 'container.storage_closet.desc',
  w = 5,
  h = 7,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_wasteland/kitchen_fridge001a.mdl', {
  name = 'container.large_fridge.title',
  desc = 'container.large_fridge.desc',
  w = 6,
  h = 8,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_wasteland/kitchen_counter001c.mdl', {
  name = 'container.counter.title',
  desc = 'container.counter.desc',
  w = 5,
  h = 5,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop({
  'models/Items/ammoCrate_Rockets.mdl',
  'models/Items/ammocrate_smg1.mdl',
  'models/Items/ammocrate_ar2.mdl',
  'models/Items/ammocrate_grenade.mdl'
},
{
  name = 'container.metal_box.title',
  desc = 'container.metal_box.desc',
  w = 7,
  h = 4,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/Items/item_item_crate.mdl', {
  name = 'container.medium_wooden_crate.title',
  desc = 'container.medium_wooden_crate.desc',
  w = 4,
  h = 4,
  open_sound = 'physics/wood/wood_box_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard5.wav'
})
Container:register_prop('models/props_lab/partsbin01.mdl', {
  name = 'container.small_parts_bin.title',
  desc = 'container.small_parts_bin.desc',
  w = 4,
  h = 2,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_interiors/Furniture_Vanity01a.mdl', {
  name = 'container.small_dresser_table.title',
  desc = 'container.small_dresser_table.desc',
  w = 3,
  h = 1,
  open_sound = 'physics/wood/wood_box_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard5.wav'
})

Container:register_prop('models/props_borealis/bluebarrel001.mdl', {
  name = 'container.medium_water_barrel.title',
  desc = 'container.medium_water_barrel.desc',
  w = 3,
  h = 6,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_c17/cashregister01a.mdl', {
  name = 'container.medium_cash_reg.title',
  desc = 'container.medium_cash_reg.desc',
  w = 4,
  h = 2,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})
