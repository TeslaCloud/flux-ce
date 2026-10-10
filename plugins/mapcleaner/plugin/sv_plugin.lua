--- Server side of the Map Cleaner plugin: works out which entities of the map are unwanted
-- and removes them.

local physics_pattern = 'prop_physics*'
local vehicle_pattern = 'prop_vehicle*'

local lua_patterns = {}

--- Turns a class pattern into a Lua pattern that has to match a whole class name.
-- The result is remembered, so every class pattern is only converted once.
-- @param pattern [String entity class in which `*` stands for any number of characters]
-- @return [String Lua pattern]
local function to_lua_pattern(pattern)
  local lua_pattern = lua_patterns[pattern]

  if !lua_pattern then
    local escaped = string.pattern_safe(pattern):gsub('%%%*', '.*')

    lua_pattern = '^'..escaped..'$'
    lua_patterns[pattern] = lua_pattern
  end

  return lua_pattern
end

--- Returns the class patterns that are currently in effect: the entries of the
-- 'remove_map_classes' config, followed by `prop_physics*` if 'remove_map_physics' is on
-- and by `prop_vehicle*` if 'remove_map_vehicles' is on. Serverside only.
-- @return [List<String> class patterns in lower case, `*` stands for any number of
--   characters]
function MapCleaner:get_patterns()
  local patterns = {}
  local classes = Config.get('remove_map_classes')

  if istable(classes) then
    for k, v in pairs(classes) do
      if isstring(v) then
        local pattern = v:strip():lower()

        if pattern != '' then
          table.insert(patterns, pattern)
        end
      end
    end
  end

  if Config.get('remove_map_physics') then
    table.insert(patterns, physics_pattern)
  end

  if Config.get('remove_map_vehicles') then
    table.insert(patterns, vehicle_pattern)
  end

  return patterns
end

--- Checks whether an entity class matches one of the class patterns. The comparison ignores
-- case. Serverside only.
-- ```
-- MapCleaner:class_matches('weapon_smg1', { 'weapon_*' })
-- -- true
--
-- MapCleaner:class_matches('prop_physics', { 'weapon_*', 'item_battery' })
-- -- false
-- ```
-- @param ent_class [String entity class]
-- @param patterns=MapCleaner:get_patterns() [List<String> class patterns in lower case, as
--   `MapCleaner:get_patterns` returns them; `*` stands for any number of characters]
-- @return [Boolean]
function MapCleaner:class_matches(ent_class, patterns)
  ent_class = ent_class:lower()

  for k, v in ipairs(patterns or self:get_patterns()) do
    if v == ent_class then
      return true
    end

    if v:find('*', 1, true) and ent_class:find(to_lua_pattern(v)) then
      return true
    end
  end

  return false
end

--- Checks whether the plugin is allowed to remove an entity at all. It is not if the entity
-- was not created by the map, which covers everything that players, the framework and
-- plugins have spawned, if it is a player, or if it is a weapon that somebody carries.
-- Serverside only.
-- @param entity [Entity]
-- @return [Boolean]
function MapCleaner:can_remove(entity)
  if !IsValid(entity) or entity:IsPlayer() or !entity:CreatedByMap() then
    return false
  end

  if entity:IsWeapon() and IsValid(entity:GetOwner()) then
    return false
  end

  return true
end

--- Decides whether an entity is to be removed from the map. Entities that the plugin may
-- not remove (see `MapCleaner:can_remove`) never are; for the others the
-- MapCleanerShouldRemove hook has the last word, and without an answer from it the entity
-- is removed if its class matches. Serverside only.
-- @param entity [Entity]
-- @param matched=nil [Boolean whether the class of the entity counts as matching; checked
--   against the patterns in effect if nil]
-- @return [Boolean]
function MapCleaner:should_remove(entity, matched)
  if !self:can_remove(entity) then
    return false
  end

  local ent_class = entity:GetClass()

  if matched == nil then
    matched = self:class_matches(ent_class)
  end

  --- Called on the server for every entity created by the map while the map is being
  -- cleaned, which happens once the map has loaded and after every map cleanup, to decide
  -- whether the entity is removed. It is not called for entities that were not created by
  -- the map nor for weapons carried by a player: those are never removed.
  -- @param entity [Entity The entity of the map that is being looked at]
  -- @param ent_class [String The class of the entity]
  -- @param matched [Boolean Whether the class matches one of the patterns in effect, that is
  --   whether the entity is removed if nothing is returned]
  -- @return [Boolean Return true to remove the entity, false to keep it]
  local result = hook.Run('MapCleanerShouldRemove', entity, ent_class, matched)

  if result != nil then
    return result != false
  end

  return matched
end

--- Removes the unwanted entities of the map: every entity created by the map for which
-- `MapCleaner:should_remove` says so. Runs the PostMapClean hook when done. Serverside only.
-- The plugin calls this once the map has loaded and after every map cleanup.
-- @return [Number how many entities have been removed]
function MapCleaner:clean()
  local patterns = self:get_patterns()
  local matches = {}
  local unwanted = {}

  for k, v in ents.Iterator() do
    local ent_class = v:GetClass()

    local matched = matches[ent_class]

    if matched == nil then
      matched = self:class_matches(ent_class, patterns)
      matches[ent_class] = matched
    end

    if self:should_remove(v, matched) then
      unwanted[#unwanted + 1] = v
    end
  end

  local count = #unwanted

  for i = 1, count do
    unwanted[i]:Remove()
  end

  Flux.dev_print('Map Cleaner: removed '..count..' map entities.')

  --- Called on the server after the map has been cleaned, that is once the map has loaded
  -- and after every map cleanup. The removed entities are still being deleted by the engine
  -- at this point and are gone on the next tick. A schema can use it to put its own
  -- entities in place of what was removed.
  -- @param count [Number How many entities have been removed]
  hook.Run('PostMapClean', count)

  return count
end
