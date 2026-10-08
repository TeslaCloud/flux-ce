--- Server side of the Mapscenes plugin: sets the default camera settings, stores the mapscene
-- points per map and sends them and their changes to the clients.

Config.set('mapscenes_speed', 15)
Config.set('mapscenes_animated', false)
Config.set('mapscenes_rotate_speed', 0.05)

--- Sends all mapscene points to a player who has finished loading.
-- @param actor [Player]
function Mapscenes:PlayerInitialized(actor)
  Cable.send(actor, 'fl_mapscene_load', self.points)
end

--- Loads the mapscene points when the framework loads its data.
function Mapscenes:LoadData()
  self:load()
end

--- Saves the mapscene points when the framework saves its data.
function Mapscenes:SaveData()
  self:save()
end

--- Writes the mapscene points to the plugin data of the current schema and map.
-- Serverside only.
function Mapscenes:save()
  Data.save_plugin('mapscenepoints', self.points)
end

--- Reads the mapscene points from the plugin data of the current schema and map, replacing
-- the current list. Does not send them to clients. Serverside only.
function Mapscenes:load()
  local points = Data.load_plugin('mapscenepoints', {})

  self.points = points
end

--- Adds a mapscene camera point, sends it to all clients and saves the list.
-- Serverside only.
-- @param pos [Vector camera position]
-- @param ang [Angle camera angles]
function Mapscenes:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  Cable.send(nil, 'fl_mapscene_add', pos, ang)

  self:save()
end

Cable.receive('fl_mapscene_remove', function(actor, id)
  if !actor:can('mapscenes') then return end
  if !isnumber(id) or !Mapscenes.points[id] then return end

  table.remove(Mapscenes.points, id)

  Cable.send(nil, 'fl_mapscene_delete', id)

  Mapscenes:save()
end)
