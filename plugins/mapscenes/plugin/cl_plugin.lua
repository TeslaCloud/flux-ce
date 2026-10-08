--- Client side of the Mapscenes plugin: keeps the local list of mapscene points in sync with
-- the server.

Cable.receive('fl_mapscene_load', function(points)
  Mapscenes.points = points or {}
end)

Cable.receive('fl_mapscene_add', function(pos, ang)
  table.insert(Mapscenes.points, {
    pos = pos,
    ang = ang
  })
end)

Cable.receive('fl_mapscene_delete', function(index)
  table.remove(Mapscenes.points, index)
end)
