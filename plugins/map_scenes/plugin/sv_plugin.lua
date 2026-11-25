--- Server side of the MapScenes plugin: stores the mapscene points per map, each with an ID it
-- is removed by, and sends them and their changes to the clients.

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
-- the current list, and gives an ID to every point that has none. Does not send them to
-- clients. Serverside only.
function MapScenes:load()
  local points = Data.load_plugin('mapscenepoints', {})
  local last_id = 0

  for _, point in ipairs(points) do
    if isnumber(point.id) then
      last_id = math.max(last_id, point.id)
    end
  end

  for _, point in ipairs(points) do
    if !isnumber(point.id) then
      last_id += 1
      point.id = last_id
    end
  end

  self.points = points
  self.last_point_id = last_id
end

--- Adds a mapscene camera point, sends it to all clients and saves the list.
-- Serverside only.
-- @param pos [Vector camera position]
-- @param ang [Angle camera angles]
-- @return [Map the point, with its `id`]
function MapScenes:add_point(pos, ang)
  local point = {
    id = (self.last_point_id or 0) + 1,
    pos = pos,
    ang = ang
  }

  self.last_point_id = point.id

  table.insert(self.points, point)

  cable_send(nil, 'fl_mapscene_add', point)

  self:save()

  return point
end

--- Removes the mapscene point with an ID, tells all clients and saves the list.
-- Serverside only.
-- @param id [Number ID of the point]
-- @return [Boolean true if there was a point with that ID]
function MapScenes:remove_point(id)
  local index = self:find_point_index(id)

  if !index then return false end

  table.remove(self.points, index)

  cable_send(nil, 'fl_mapscene_delete', id)

  self:save()

  return true
end
