cable.receive('flLoadMapscene', function(points)
  flMapscenes.points = points or {}
end)

cable.receive('flAddMapscene', function(pos, ang)
  table.insert(flMapscenes.points, {
    pos = pos,
    ang = ang
  })
end)

cable.receive('flDeleteMapscene', function(index)
  table.remove(flMapscenes.points, index)
end)
