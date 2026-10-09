--- Spawn Points lets staff choose where players appear on the map.
-- A spawn point is a position, a facing direction and a group. The group says who the point
-- is for: `default` is for everyone, `faction:<faction ID>` for the characters of a faction
-- and `class:<class ID>` for the holders of a class. Factions need the Factions plugin and
-- classes the Classes plugin; the plugin works without either, with default points only.
-- Points are saved separately for every map.
--
-- Staff with the 'spawnpoints' permission place and remove points with the Spawn Point Tool.
-- While the tool is held, every point is drawn in the world as a box of the size of a player
-- with a line that shows its direction and a label that names its group.
--
-- When a player spawns, the server looks at the groups the player belongs to, the most
-- specific one first: their class, then their faction, then `default`. The first group that
-- has any points is used, and the player is put at a random point of it that nobody is
-- standing on. Without any points the map's own spawn is used. The `GetPlayerSpawnPoint`
-- hook can replace the choice or turn it down.
--
-- The point is handed to the game through `PlayerSelectSpawn`, the same way a map's spawn
-- entity would be, so the player is never moved after they have spawned. A plugin that puts
-- a player back where they were can simply set their position once they have spawned.
-- ```
-- -- Server: a point for everyone and a point for the 'police' faction.
-- SpawnPoints:add_point(Vector(0, 0, 64), Angle(0, 90, 0))
-- SpawnPoints:add_point(Vector(512, 0, 64), Angle(0, 180, 0), 'faction:police')
-- ```
-- @module [SpawnPoints]

PLUGIN:set_global('SpawnPoints')

SpawnPoints.points = SpawnPoints.points or {}
SpawnPoints.hull_mins = Vector(-16, -16, 0)
SpawnPoints.hull_maxs = Vector(16, 16, 72)

require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

local color_default = Color(120, 200, 255)
local box_angle = Angle(0, 0, 0)

--- Registers the 'spawnpoints' level design permission.
function SpawnPoints:RegisterPermissions()
  Bolt:register_permission(
    'spawnpoints',
    'Manage spawn points',
    'Grants access to place and remove spawn points.',
    'permission.categories.level_design',
    'moderator'
  )
end

--- Builds the name of a spawn point group.
-- ```
-- SpawnPoints:make_group('faction', 'police') -- 'faction:police'
-- SpawnPoints:make_group('default') -- 'default'
-- ```
-- @param kind [String 'default', 'faction' or 'class']
-- @param id=nil [String faction ID or class ID; not used for 'default']
-- @return [String the group, 'default' when the kind is 'default' or there is no ID]
function SpawnPoints:make_group(kind, id)
  if kind == 'default' or !isstring(kind) or !isstring(id) or id == '' then
    return 'default'
  end

  return kind..':'..id
end

--- Takes the name of a spawn point group apart.
-- ```
-- local kind, id = SpawnPoints:split_group('class:medic') -- 'class', 'medic'
-- ```
-- @param group [String group, such as 'default' or 'faction:police']
-- @return [String 'default', 'faction', 'class' or whatever precedes the colon; nil when the
--   group is not a group name at all, String the faction ID or class ID; nil for 'default']
function SpawnPoints:split_group(group)
  if !isstring(group) then return end

  if group == 'default' then
    return 'default'
  end

  return group:match('^(%l+):(.+)$')
end

--- Checks whether a group can be given spawn points right now: it is `default`, a
-- registered faction or a registered class. Points of a group that is not valid any more are
-- kept, but no player belongs to it.
-- @param group [String group, such as 'default' or 'faction:police']
-- @return [Boolean]
function SpawnPoints:is_valid_group(group)
  local kind, id = self:split_group(group)

  if kind == 'default' then
    return true
  elseif kind == 'faction' then
    return Factions != nil and Factions.find_by_id(id) != nil
  elseif kind == 'class' then
    return Classes != nil and Classes.find_by_id(id) != nil
  end

  return false
end

--- Returns every group that spawn points can be placed for: `default`, then the registered
-- factions, then the registered classes, each sorted by ID.
-- @return [List<String> groups]
function SpawnPoints:get_groups()
  local groups = { 'default' }

  if Factions then
    local ids = table.GetKeys(Factions.all())

    table.sort(ids)

    for k, v in ipairs(ids) do
      table.insert(groups, self:make_group('faction', v))
    end
  end

  if Classes then
    local ids = table.GetKeys(Classes.all())

    table.sort(ids)

    for k, v in ipairs(ids) do
      table.insert(groups, self:make_group('class', v))
    end
  end

  return groups
end

--- Returns the name of who a group stands for: the name of the faction or of the class, or
-- the 'ui.spawnpoints.group.default' phrase for `default`. The name can be a language phrase
-- and is not translated here.
-- @param group [String group, such as 'default' or 'faction:police']
-- @return [String name or language phrase; the ID when the faction or class is not registered]
function SpawnPoints:get_group_name(group)
  local kind, id = self:split_group(group)

  if kind == 'default' then
    return 'ui.spawnpoints.group.default'
  elseif kind == 'faction' and Factions then
    local faction_table = Factions.find_by_id(id)

    if faction_table then
      return faction_table.name
    end
  elseif kind == 'class' and Classes then
    local class_table = Classes.find_by_id(id)

    if class_table then
      return class_table:get_name()
    end
  end

  return id or tostring(group)
end

--- Returns the translated text that describes a group in the tool settings and on the
-- labels of the points, such as 'Everyone', 'Faction: Police' or 'Class: Medic'.
-- @param group [String group, such as 'default' or 'faction:police']
-- @return [String]
function SpawnPoints:get_group_label(group)
  local kind = self:split_group(group)
  local label = t(self:get_group_name(group))

  if kind == 'faction' or kind == 'class' then
    label = t('ui.spawnpoints.group.'..kind, { name = label:gsub('%%', '%%%%') })
  end

  return label
end

--- Returns the color a group is drawn with: the color of the faction or of the class, or
-- light blue for `default` and for groups that are not valid any more.
-- @param group [String group, such as 'default' or 'faction:police']
-- @return [Color]
function SpawnPoints:get_group_color(group)
  local kind, id = self:split_group(group)

  if kind == 'faction' and Factions then
    local faction_table = Factions.find_by_id(id)

    if faction_table and faction_table.color then
      return faction_table.color
    end
  elseif kind == 'class' and Classes then
    local class_table = Classes.find_by_id(id)

    if class_table then
      return class_table:get_color()
    end
  end

  return color_default
end

--- Returns the spawn points of a group, or all of them. The server knows every point; a
-- client only knows them while the local player has the 'spawnpoints' permission and has
-- held the Spawn Point Tool.
-- @param group=nil [String group to return the points of; every point if nil]
-- @return [List<Map> points, each with pos, ang and group; a new list that is safe to change]
function SpawnPoints:get_points(group)
  local points = {}

  for k, v in ipairs(self.points) do
    if group == nil or v.group == group then
      table.insert(points, v)
    end
  end

  return points
end

--- Finds the spawn point a ray runs through, taking each point for a box of the size of a
-- player. When the ray runs through several points, the first one it enters is returned.
-- ```
-- local index, point = SpawnPoints:find_aimed_point(actor:GetShootPos(), actor:GetAimVector(), 1024)
-- ```
-- @param start [Vector where the ray starts]
-- @param direction [Vector normalized direction of the ray]
-- @param distance [Number length of the ray]
-- @return [Number index of the point in SpawnPoints.points, Map the point; nothing if the ray
--   does not run through any point]
function SpawnPoints:find_aimed_point(start, direction, distance)
  local delta = direction * distance
  local found_index, found_fraction

  for k, v in ipairs(self.points) do
    local hit_pos, hit_normal, fraction = util.IntersectRayWithOBB(
      start, delta, v.pos, box_angle, self.hull_mins, self.hull_maxs
    )

    if hit_pos and (!found_fraction or (fraction or 0) < found_fraction) then
      found_index = k
      found_fraction = fraction or 0
    end
  end

  if found_index then
    return found_index, self.points[found_index]
  end
end

--- Finds the spawn point that is closest to a position.
-- @param pos [Vector]
-- @param radius=64 [Number how far from the position a point may be]
-- @return [Number index of the point in SpawnPoints.points, Map the point; nothing if there
--   is no point within the radius]
function SpawnPoints:find_nearest_point(pos, radius)
  local found_index
  local found_distance = (radius or 64) ^ 2

  for k, v in ipairs(self.points) do
    local distance = v.pos:DistToSqr(pos)

    if distance <= found_distance then
      found_index = k
      found_distance = distance
    end
  end

  if found_index then
    return found_index, self.points[found_index]
  end
end
