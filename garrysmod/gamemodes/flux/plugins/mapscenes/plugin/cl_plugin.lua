cable.receive('flLoadMapscene', function(points)
  Mapscenes.points = points or {}
end)

cable.receive('flAddMapscene', function(pos, ang)
  table.insert(Mapscenes.points, {
    pos = pos,
    ang = ang
  })
end)

cable.receive('flDeleteMapscene', function(index)
  table.remove(Mapscenes.points, index)
end)
