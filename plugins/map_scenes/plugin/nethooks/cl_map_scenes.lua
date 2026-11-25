--- Client-side receivers of the MapScenes plugin: they keep the local list of mapscene points
-- in sync with the server.

Cable.receive('fl_mapscene_load', function(points)
  MapScenes.points = points or {}
end)

Cable.receive('fl_mapscene_add', function(point)
  table.insert(MapScenes.points, point)
end)

Cable.receive('fl_mapscene_delete', function(id)
  local index = MapScenes:find_point_index(id)

  if index then
    table.remove(MapScenes.points, index)
  end
end)
