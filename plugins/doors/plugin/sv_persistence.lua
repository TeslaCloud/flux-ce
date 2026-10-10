--- Saving and loading of door ownership, serverside.
-- `Doors:get_ownership_data` turns the ownership state of a door into what `Doors:save`
-- writes under its `ownership` key, `Doors:set_ownership_data` applies what `Doors:load`
-- reads back, and `Doors:restore_links` links the loaded doors into their groups again once
-- every door has been loaded.

local IsValid = IsValid
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

  for k, v in pairs(state.access or {}) do
    table.insert(access, { id = k, name = v.name, level = v.level })
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
    for k, v in pairs(data.access) do
      local character_id = istable(v) and tonumber(v.id)
      local level = istable(v) and tonumber(v.level)

      if character_id and level and level > DOOR_ACCESS_NONE and character_id != state.owner.id then
        state.access[character_id] = {
          level = math.min(math.floor(level), DOOR_ACCESS_MANAGE),
          name = isstring(v.name) and v.name or ''
        }
      end
    end
  end
end

--- Links the loaded doors to their main doors again and networks the ownership state of
-- every loaded door. Nothing is saved, since the doors are as they were saved.
-- @param doors [List<Entity> the doors that were loaded]
function Doors:restore_links(doors)
  for k, v in ipairs(doors) do
    local parent_id = v.door_parent_id

    if parent_id then
      v.door_parent_id = nil

      local parent = ents.GetMapCreatedEntity(parent_id)

      if IsValid(parent) and parent:is_door() and parent != v and self:get_root(v) != self:get_root(parent) then
        self:attach(v, self:get_root(parent))
      end
    end
  end

  for k, v in ipairs(doors) do
    if !IsValid(v.door_parent) then
      self:sync(v)
    end
  end
end
