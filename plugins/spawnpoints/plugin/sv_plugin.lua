--- Server side of the Spawn Points plugin: stores the spawn points of the map, adds and
-- removes them, sends them to the staff who edit them and picks the point a player spawns at.

--- Reads the spawn points of the current schema and map from the plugin data, replacing the
-- current list. Does not send them to clients.
function SpawnPoints:load()
  local stored = Data.load_plugin('spawnpoints', {})
  local points = {}

  if istable(stored) then
    for k, v in ipairs(stored) do
      if istable(v) and isnumber(v.x) and isnumber(v.y) and isnumber(v.z) then
        points[#points + 1] = {
          pos = Vector(v.x, v.y, v.z),
          ang = Angle(0, tonumber(v.yaw) or 0, 0),
          group = isstring(v.group) and v.group or 'default'
        }
      end
    end
  end

  self.points = points
end

--- Writes the spawn points to the plugin data of the current schema and map. Positions are
-- stored as plain numbers and the direction as a yaw angle.
function SpawnPoints:save()
  local stored = {}

  for k, v in ipairs(self.points) do
    local pos = v.pos

    stored[k] = {
      x = pos.x,
      y = pos.y,
      z = pos.z,
      yaw = v.ang.y,
      group = v.group
    }
  end

  Data.save_plugin('spawnpoints', stored)
end

--- Sends the whole list of spawn points to the clients that draw them. Only players with the
-- 'spawnpoints' permission are ever sent the points.
-- @param target=nil [Player who to send the points to; every player with the 'spawnpoints'
--   permission if nil]
function SpawnPoints:sync(target)
  local receivers = {}

  if target != nil then
    if IsValid(target) and target:IsPlayer() then
      receivers[1] = target
    end
  else
    for k, v in player.Iterator() do
      if !v:IsBot() and v:can('spawnpoints') then
        receivers[#receivers + 1] = v
      end
    end
  end

  if #receivers == 0 then return end

  Cable.send(receivers, 'fl_spawnpoints_load', self.points)
end

--- Adds a spawn point, saves the list and sends it to the staff who edit spawn points.
-- The group is stored as it is given, so that points can be placed for a faction before it
-- is registered; see `SpawnPoints:is_valid_group` for checking it first.
-- ```
-- SpawnPoints:add_point(actor:GetPos(), actor:EyeAngles(), SpawnPoints:make_group('faction', 'police'))
-- ```
-- @param pos [Vector where the feet of a spawning player are put]
-- @param ang=nil [Angle the direction a spawning player faces; only the yaw is kept]
-- @param group='default' [String group the point is for, see `SpawnPoints:make_group`]
-- @return [Map the new point with its pos, ang and group; nil if the position is not a vector]
function SpawnPoints:add_point(pos, ang, group)
  if !isvector(pos) then return end

  local point = {
    pos = Vector(pos.x, pos.y, pos.z),
    ang = Angle(0, isangle(ang) and ang.y or 0, 0),
    group = isstring(group) and group != '' and group or 'default'
  }

  local points = self.points

  points[#points + 1] = point

  self:save()
  self:sync()

  return point
end

--- Removes a spawn point, saves the list and sends it to the staff who edit spawn points.
-- Removing a point changes the indexes of the points after it.
-- @param index [Number index of the point in SpawnPoints.points]
-- @return [Map the removed point, or nil if there is no point with that index]
function SpawnPoints:remove_point(index)
  if !isnumber(index) or !self.points[index] then return end

  local point = table.remove(self.points, index)

  self:save()
  self:sync()

  return point
end

--- Finds the spot on the ground where a player stands, or the spot they would land on when
-- they are in the air or noclipping. This is where the Spawn Point Tool puts a new point.
-- @param actor [Player]
-- @return [Vector position for the feet of a player; nil if the player is inside of something
--   solid or there is no ground below them]
function SpawnPoints:get_floor_position(actor)
  local pos = actor:GetPos()

  if actor:IsOnGround() then
    return pos
  end

  local trace = util.TraceHull({
    start = pos,
    endpos = pos - Vector(0, 0, 8192),
    mins = self.hull_mins,
    maxs = self.hull_maxs,
    mask = MASK_PLAYERSOLID,
    filter = player.GetAll()
  })

  if trace.StartSolid or !trace.Hit then return end

  return trace.HitPos
end

--- Checks whether a player can be put on a spawn point without getting stuck in another
-- player. Only living, solid players count as being in the way.
-- @param point [Map spawn point]
-- @param ignore=nil [Player a player who is not in the way, usually the one who is spawning]
-- @return [Boolean]
function SpawnPoints:is_point_free(point, ignore)
  local pos = point.pos
  local found = ents.FindInBox(pos + self.hull_mins, pos + self.hull_maxs)

  for i = 1, #found do
    local v = found[i]

    if v:IsPlayer() and v != ignore and v:Alive() and v:IsSolid() then
      return false
    end
  end

  return true
end

--- Picks a random point of a list, preferring the points that nobody stands on. When all of
-- them are taken, any of them may be picked.
-- @param points [List<Map> spawn points to pick from]
-- @param ignore=nil [Player a player who is not in the way, usually the one who is spawning]
-- @return [Map the picked point, or nil if the list is empty]
function SpawnPoints:pick_point(points, ignore)
  if #points == 0 then return end

  local free = {}
  local free_count = 0

  for k, v in ipairs(points) do
    if self:is_point_free(v, ignore) then
      free_count = free_count + 1
      free[free_count] = v
    end
  end

  if free_count > 0 then
    return free[math.random(free_count)]
  end

  return points[math.random(#points)]
end

--- Returns the spawn point groups a player belongs to, the most specific one first: the
-- faction of their character, then `default`. They are read from the character itself,
-- which is already in place when the player is spawned for a character that is being
-- loaded.
-- @param actor [Player]
-- @return [List<String> groups; always ends with 'default']
function SpawnPoints:get_player_groups(actor)
  local groups = {}
  local character = Characters and actor:is_character_loaded() and actor:get_character()

  if istable(character) and Factions and isstring(character.faction) then
    groups[1] = self:make_group('faction', character.faction)
  end

  if groups[#groups] != 'default' then
    groups[#groups + 1] = 'default'
  end

  return groups
end

--- Chooses the spawn point for a player: a random free point of the first of the player's
-- groups that has any points. The `GetPlayerSpawnPoint` hook can replace the choice.
-- @param actor [Player]
-- @return [Map the point to spawn the player at, with a pos and possibly an ang; nil to
--   leave the player to the spawn of the map]
-- @see [SpawnPoints:get_player_groups]
function SpawnPoints:choose_point(actor)
  local points = {}

  for k, v in ipairs(self:get_player_groups(actor)) do
    points = self:get_points(v)

    if #points > 0 then break end
  end

  local point = self:pick_point(points, actor)

  --- Lets plugins decide where a player spawns. Called on the server every time a player
  -- spawns, after the Spawn Points plugin has made its own choice and before the game
  -- places the player. With the Characters plugin loaded it is only called for players who
  -- have an active character that is not banned; it is never called for level transitions.
  -- @param actor [Player the player who is spawning]
  -- @param point [Map the spawn point that has been picked, with its pos, ang and group; nil
  --   when the player's groups have no points]
  -- @param points [List<Map> all the points of the group the point was picked from; empty
  --   when the player's groups have no points]
  -- @return [Map/Boolean A table with a `pos` vector and optionally an `ang` angle to spawn
  --   the player there instead, or false to use the spawn of the map; return nothing to
  --   keep the picked point]
  local override = hook.Run('GetPlayerSpawnPoint', actor, point, points)

  if override == false then
    return
  elseif istable(override) and isvector(override.pos) then
    return override
  end

  return point
end

--- Returns the entity that stands in for the chosen spawn point. The game only spawns
-- players at entities, so the plugin keeps one invisible point entity and moves it to the
-- point a player is about to spawn at. It is created again if something has removed it.
-- @warning [Internal]
-- @return [Entity the stand-in entity; nil if it could not be created]
function SpawnPoints:get_anchor()
  if !IsValid(self.anchor) then
    local anchor = ents.Create('info_target')

    if !IsValid(anchor) then return end

    anchor:Spawn()

    self.anchor = anchor
  end

  return self.anchor
end

Cable.receive('fl_spawnpoints_request', function(actor)
  if !actor:can('spawnpoints') then return end

  local cur_time = CurTime()

  if (actor.next_spawnpoints_request or 0) > cur_time then return end

  actor.next_spawnpoints_request = cur_time + 1

  SpawnPoints:sync(actor)
end)
