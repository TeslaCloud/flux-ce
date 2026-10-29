--- Server side of the MapScenes plugin: stores the mapscene points per map and sends them and
-- their changes to the clients.

local cable_send = Cable.send

--- Sends all mapscene points to a player who has finished loading.
-- @param actor [Player]
function MapScenes:PlayerInitialized(actor)
  cable_send(actor, 'fl_mapscene_load', self.points)
end

--- Loads the mapscene points when the framework loads its data.
function MapScenes:LoadData()
  self:load()
end

--- Saves the mapscene points when the framework saves its data.
function MapScenes:SaveData()
  self:save()
end

--- Writes the mapscene points to the plugin data of the current schema and map.
-- Serverside only.
function MapScenes:save()
  Data.save_plugin('mapscenepoints', self.points)
end

--- Reads the mapscene points from the plugin data of the current schema and map, replacing
-- the current list. Does not send them to clients. Serverside only.
function MapScenes:load()
  local points = Data.load_plugin('mapscenepoints', {})

  self.points = points
end

--- Adds a mapscene camera point, sends it to all clients and saves the list.
-- Serverside only.
-- @param pos [Vector camera position]
-- @param ang [Angle camera angles]
function MapScenes:add_point(pos, ang)
  table.insert(self.points, {
    pos = pos,
    ang = ang
  })

  cable_send(nil, 'fl_mapscene_add', pos, ang)

  self:save()
end
