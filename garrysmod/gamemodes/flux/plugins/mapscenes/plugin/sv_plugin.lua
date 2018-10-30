config.set('mapscenes_speed', 15)
config.set('mapscenes_animated', false)
config.set('mapscenes_rotate_speed', 0.05)

function Mapscenes:save()
  data.save_plugin('mapscenepoints', Mapscenes.points)
end

function Mapscenes:load()
  local points = data.load_plugin('mapscenepoints', {})

  self.points = points
end

function Mapscenes:LoadData()
  self:load()
end

function Mapscenes:SaveData()
  self:save()
end

function Mapscenes:PlayerInitialized(player)
  cable.send(player, 'flLoadMapscene', self.points)
end

function Mapscenes:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  cable.send(nil, 'flAddMapscene', pos, ang)

  self:save()
end

cable.receive('flRemoveMapscene', function(player, id)
  table.remove(Mapscenes.points, id)

  cable.send(nil, 'flDeleteMapscene', id)

  Mapscenes:save()
end)
