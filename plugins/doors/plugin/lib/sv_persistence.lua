--- Saving and loading of door ownership, serverside.
-- `Doors:get_ownership_data` turns the ownership state of a door into what `Doors:save`
-- writes under its `ownership` key, `Doors:set_ownership_data` applies what `Doors:load`
-- reads back, `Doors:restore_links` links the loaded doors into their groups again once
-- every door has been loaded, and `Doors:release_missing_owners` releases the loaded doors
-- whose owners do not exist anymore.

if !Doors then
  PLUGIN:set_global('Doors')
end

local IsValid = IsValid
local ipairs = ipairs
local pairs = pairs
local istable = istable
local isstring = isstring
local tonumber = tonumber

--- Returns the ownership of a door in the form it is saved in.
-- @param entity [Entity the door]
-- @return [Map `parent` (the map creation ID of the main door) for a door that is linked to
--   another, or `owner`, `access` (a List of Maps with id, name and level) and `text` for
--   a door that has an owner; nil if there is nothing to save]
function Doors:get_ownership_data(entity)
  local parent = entity.door_parent

  if IsValid(parent) then
    return { parent = parent:MapCreationID() }
  end

  local state = entity.door_state

  if !state or !state.owner then return end

  local access = {}

  for character_id, entry in pairs(state.access or {}) do
    table.insert(access, { id = character_id, name = entry.name, level = entry.level })
  end

  return {
    owner = state.owner,
    access = access,
    text = state.text
  }
end

--- Applies saved ownership to a door. The link of a door to its main door is only
-- remembered here; `Doors:restore_links` makes it once every door has been loaded.
-- @param entity [Entity the door]
-- @param data [Map what `Doors:get_ownership_data` returned for the door; anything else
--   is ignored]
function Doors:set_ownership_data(entity, data)
  if !istable(data) then return end

  if data.parent then
    entity.door_parent_id = tonumber(data.parent)

    return
  end

  local owner = data.owner

  if !istable(owner) or !tonumber(owner.id) then return end

  local state = self:get_state(entity)

  state.owner = {
    id = tonumber(owner.id),
    name = isstring(owner.name) and owner.name or '',
    paid = tonumber(owner.paid) or 0,
    currency = isstring(owner.currency) and owner.currency or nil
  }
  state.access = {}
  state.text = isstring(data.text) and data.text != '' and data.text or nil

  if istable(data.access) then
    for _, entry in pairs(data.access) do
      local character_id = istable(entry) and tonumber(entry.id)
      local level = istable(entry) and tonumber(entry.level)

      if character_id and level and level > DOOR_ACCESS_NONE and character_id != state.owner.id then
        state.access[character_id] = {
          level = math.min(math.floor(level), DOOR_ACCESS_MANAGE),
          name = isstring(entry.name) and entry.name or ''
        }
      end
    end
  end
end

--- Links the loaded doors to their main doors again and networks the ownership state of
-- every loaded door. Nothing is saved, since the doors are as they were saved.
-- @param doors [List<Entity> the doors that were loaded]
function Doors:restore_links(doors)
  for _, door in ipairs(doors) do
    local parent_id = door.door_parent_id

    if parent_id then
      door.door_parent_id = nil

      local parent = ents.GetMapCreatedEntity(parent_id)

      if IsValid(parent) and parent:is_door() and parent != door and self:get_root(door) != self:get_root(parent) then
        self:attach(door, self:get_root(parent))
      end
    end
  end

  for _, door in ipairs(doors) do
    if !IsValid(door.door_parent) then
      self:sync(door)
    end
  end
end

--- Releases the loaded doors whose owning characters do not exist anymore, such as characters
-- that were deleted while the server was on another map. The owners of all the doors are
-- looked up with one query; a door that has changed hands while the query ran is left alone. The
-- doors are saved if any of them was released. Does nothing while the Characters plugin is
-- not loaded.
-- @param doors [List<Entity> the doors that were loaded]
function Doors:release_missing_owners(doors)
  if !Characters then return end

  local owners = {}
  local ids = {}
  local listed = {}

  for _, door in ipairs(doors) do
    local owner = IsValid(door) and !IsValid(door.door_parent) and self:get_owner(door)

    if owner then
      owners[door] = owner

      if !listed[owner.id] then
        listed[owner.id] = true
        ids[#ids + 1] = owner.id
      end
    end
  end

  if #ids == 0 then return end

  Character:where({ id = ids }):get(function(characters)
    local existing = {}
    local released = false

    for _, character in ipairs(characters) do
      existing[tonumber(character.id)] = true
    end

    for door, owner in pairs(owners) do
      if IsValid(door) and !existing[owner.id] and self:get_owner(door) == owner then
        self:clear_owner(door)

        released = true
      end
    end

    if released then
      self:save()
    end
  end):fetch()
end
