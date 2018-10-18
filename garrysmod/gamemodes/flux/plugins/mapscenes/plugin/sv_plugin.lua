function flMapscene:save()
  data.save_plugin('mapsceneanim', flMapscene.anim)
  data.save_plugin('mapscenepoints', flMapscene.points)
end

function flMapscene:load()
  local anim = data.load_plugin('mapsceneanim', {})
  local points = data.load_plugin('mapscenepoints', {})

  self.anim = anim
  self.points = points
end

function flMapscene:LoadData()
  self:load()
end

function flMapscene:SaveData()
  self:save()
end

function flMapscene:PlayerInitialized(player)
  netstream.Start(player, 'flLoadMapscene', self.anim, self.points)
end

function flMapscene:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  netstream.Start(nil, 'flAddMapscene', pos, ang)

  self:save()
end
