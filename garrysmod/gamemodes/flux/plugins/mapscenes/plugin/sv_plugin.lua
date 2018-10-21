config.set('mapscenes_speed', 15)
config.set('mapscenes_animated', false)
config.set('mapscenes_rotate_speed', 0.05)

function flMapscenes:save()
  data.save_plugin('mapscenepoints', flMapscenes.points)
end

function flMapscenes:load()
  local points = data.load_plugin('mapscenepoints', {})

  self.points = points
end

function flMapscenes:LoadData()
  self:load()
end

function flMapscenes:SaveData()
  self:save()
end

function flMapscenes:PlayerInitialized(player)
  netstream.Start(player, 'flLoadMapscene', self.anim, self.points)
end

function flMapscenes:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  netstream.Start(nil, 'flAddMapscene', pos, ang)

  self:save()
end

netstream.Hook('flRemoveMapscene', function(player, id)
  print(id)
  table.remove(flMapscenes.points, id)

  netstream.Start(nil, 'flDeleteMapscene', id)

  flMapscenes:save()
end)
