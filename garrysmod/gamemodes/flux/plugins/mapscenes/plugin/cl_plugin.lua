cable.receive('fl_mapscene_load', function(points)
  Mapscenes.points = points or {}
end)

cable.receive('fl_mapscene_add', function(pos, ang)
  table.insert(Mapscenes.points, {
    pos = pos,
    ang = ang
  })
end)

cable.receive('fl_mapscene_delete', function(index)
  table.remove(Mapscenes.points, index)
end)
