Config.set('mapscenes_speed', 15)
Config.set('mapscenes_animated', false)
Config.set('mapscenes_rotate_speed', 0.05)

function Mapscenes:PlayerInitialized(player)
  Cable.send(player, 'fl_mapscene_load', self.points)
end

function Mapscenes:LoadData()
  self:load()
end

function Mapscenes:SaveData()
  self:save()
end

function Mapscenes:save()
  Data.save_plugin('mapscenepoints', self.points)
end

function Mapscenes:load()
  local points = Data.load_plugin('mapscenepoints', {})

  self.points = points
end

function Mapscenes:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  Cable.send(nil, 'fl_mapscene_add', pos, ang)

  self:save()
end

Cable.receive('fl_mapscene_remove', function(player, id)
  table.remove(Mapscenes.points, id)

  Cable.send(nil, 'fl_mapscene_delete', id)

  Mapscenes:save()
end)
