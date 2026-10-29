--- Client side of the MapScenes plugin: keeps the local list of mapscene points in sync with
-- the server.

Cable.receive('fl_mapscene_load', function(points)
  MapScenes.points = points or {}
end)

Cable.receive('fl_mapscene_add', function(pos, ang)
  table.insert(MapScenes.points, {
    pos = pos,
    ang = ang
  })
end)

Cable.receive('fl_mapscene_delete', function(index)
  table.remove(MapScenes.points, index)
end)
