--- The registry of the Containers plugin: the models whose props are containers, with the
-- size of their inventory, their name, description and sounds, and the shared queries about
-- a container: its name, whether it has a password and the items it can be filled with.

if !Containers then
  PLUGIN:set_global('Containers')
end

local stored = Containers.stored or {}
Containers.stored = stored

local lowercase_models = {}

--- Makes props with the specified model(s) work as containers.
-- ```
-- Containers:register_prop('models/props_c17/FurnitureDrawer002a.mdl', {
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
function Containers:register_prop(model, data)
  if istable(model) then
    for _, model_path in pairs(model) do
      stored[model_path:lower()] = data
    end
  else
    stored[model:lower()] = data
  end
end

--- Returns all the registered containers.
-- @return [Map container data, keyed by the lowercase path to the model]
function Containers:all()
  return stored
end

--- Finds the container data that is registered for the model.
-- @param model [String path to the model; case-insensitive]
-- @return [Map container data, or nil if the model is not a container]
function Containers:find(model)
  if !isstring(model) then return end

  local lowercase = lowercase_models[model]

  if !lowercase then
    lowercase = model:lower()
    lowercase_models[model] = lowercase
  end

  return stored[lowercase]
end

--- Returns the container data of an entity, if the entity is a container: a valid
-- physics prop with a registered model.
-- @param entity [Entity]
-- @return [Map container data, or nil if the entity is not a container]
function Containers:get_container_data(entity)
  if !isentity(entity) or !IsValid(entity) or entity:GetClass() != 'prop_physics' then return end

  local model = entity:GetModel()

  if isstring(model) then
    return self:find(model)
  end
end

--- Checks whether an entity is a container: a valid physics prop with a registered model.
-- @param entity [Entity]
-- @return [Boolean]
function Containers:is_container(entity)
  return self:get_container_data(entity) != nil
end

--- Returns the name of a container: the one it was given with
-- `Containers:set_container_name`, or else the name that is registered for its model.
-- ```
-- local name, is_custom = Containers:get_container_name(entity)
-- local text = is_custom and name or t(name)
-- ```
-- @param entity [Entity the container prop]
-- @return [String the custom name as it was entered, or the language phrase of the default
--   name; nil if the model of the entity is not registered, Boolean true if the name is a
--   custom one]
function Containers:get_container_name(entity)
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
function Containers:has_container_password(entity)
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
function Containers:get_loot_items(category)
  local items = {}

  for _id, item_table in pairs(Item.all()) do
    if !item_table.is_base and item_table.lootable != false
    and (!category or item_table.category == category) then
      items[#items + 1] = item_table
    end
  end

  return items
end

--- Returns the categories of the items that containers can be filled with.
-- @return [List<String> item category IDs in alphabetical order]
function Containers:get_loot_categories()
  local categories = {}
  local seen = {}

  for _, item_table in ipairs(self:get_loot_items()) do
    local category = item_table.category

    if isstring(category) and !seen[category] then
      seen[category] = true

      categories[#categories + 1] = category
    end
  end

  table.sort(categories)

  return categories
end
