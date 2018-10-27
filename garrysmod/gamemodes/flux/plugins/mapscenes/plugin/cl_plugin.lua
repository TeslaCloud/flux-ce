cable.receive('flLoadMapscene', function(anim, points)
  flMapscenes.anim = anim
  flMapscenes.points = points
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
