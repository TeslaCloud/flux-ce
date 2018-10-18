netstream.Hook('flLoadMapscene', function(anim, points)
  flMapscene.anim = anim
  flMapscene.points = points
end)

netstream.Hook('flAddMapscene', function(pos, ang)
  table.insert(flMapscene.points, {
    pos = pos,
    ang = ang
  })
end)

netstream.Hook('flDeleteMapscene', function(index)
  table.remove(flMapscene.points, index)
end)
