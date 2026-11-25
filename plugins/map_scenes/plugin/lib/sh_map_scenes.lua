--- Shared helper of the MapScenes plugin: the lookup of a mapscene point by its ID.

if !MapScenes then
  PLUGIN:set_global('MapScenes')
end

--- Finds the position of the mapscene point with an ID in `MapScenes.points`.
-- @param id [Number ID of the point]
-- @return [Number the index in the list, or nil if no point has that ID]
function MapScenes:find_point_index(id)
  local points = self.points

  for index = 1, #points do
    if points[index].id == id then
      return index
    end
  end
end
