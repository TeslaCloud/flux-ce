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
  cable.send(player, 'flLoadMapscene', self.points)
end

function flMapscenes:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  cable.send(nil, 'flAddMapscene', pos, ang)

  self:save()
end

cable.receive('flRemoveMapscene', function(player, id)
  table.remove(flMapscenes.points, id)

  cable.send(nil, 'flDeleteMapscene', id)

  flMapscenes:save()
end)
