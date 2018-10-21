netstream.Hook('flLoadMapscene', function(anim, points)
  flMapscenes.anim = anim
  flMapscenes.points = points
end)

netstream.Hook('flAddMapscene', function(pos, ang)
  table.insert(flMapscenes.points, {
    pos = pos,
    ang = ang
  })
end)

netstream.Hook('flDeleteMapscene', function(index)
  table.remove(flMapscenes.points, index)
end)
