config.set('mapscenes_speed', 15)
config.set('mapscenes_animated', false)
config.set('mapscenes_rotate_speed', 0.05)

function Mapscenes:PlayerInitialized(player)
  cable.send(player, 'fl_mapscene_load', self.points)
end

function Mapscenes:LoadData()
  self:load()
end

function Mapscenes:SaveData()
  self:save()
end

function Mapscenes:save()
  data.save_plugin('mapscenepoints', self.points)
end

function Mapscenes:load()
  local points = data.load_plugin('mapscenepoints', {})

  self.points = points
end

function Mapscenes:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  cable.send(nil, 'fl_mapscene_add', pos, ang)

  self:save()
end

cable.receive('fl_mapscene_remove', function(player, id)
  table.remove(Mapscenes.points, id)

  cable.send(nil, 'fl_mapscene_delete', id)

  Mapscenes:save()
end)
