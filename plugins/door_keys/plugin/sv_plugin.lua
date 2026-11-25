--- Server side of the Door Keys plugin: the door list of a key. A key keeps an entry for every
-- door it belongs to, with the map of the door and its map creation ID, so that a key never
-- opens a door of another map.

--- Returns the entry that a key keeps for a door.
-- @param entity [Entity the door]
-- @return [Map the map (String) and the map creation ID (Number) of the door]
function DoorKeys:get_door_entry(entity)
  return { map = game.GetMap(), id = entity:MapCreationID() }
end

--- Finds the entry of a door in the door list of a key.
-- @param doors [List<Map> the door list of the key, its 'doors' data]
-- @param entity [Entity the door]
-- @return [Number index of the entry in the list, nil if the door is not in it]
function DoorKeys:find_door_entry(doors, entity)
  local map, door_id = game.GetMap(), entity:MapCreationID()

  for index, entry in ipairs(doors) do
    if istable(entry) and entry.map == map and entry.id == door_id then
      return index
    end
  end
end

--- Checks whether a key opens a door: it does if it belongs to the door or to a door that is
-- linked with it.
-- @param key_item [Item the key]
-- @param entity [Entity the door]
-- @return [Boolean]
function DoorKeys:opens(key_item, entity)
  local doors = key_item:get_data('doors', {})

  for _, door in ipairs(Doors:get_group(entity)) do
    if self:find_door_entry(doors, door) then
      return true
    end
  end

  return false
end
