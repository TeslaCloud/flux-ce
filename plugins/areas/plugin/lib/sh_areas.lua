--- Areas are named regions of the map, made of one or more polygons with a floor and a
-- height, that the server tracks players entering and leaving.
-- Every area has a type registered with `Areas.register_type`. The type's callback runs
-- when a player enters or leaves an area of that type, on the server and on that player's
-- client. An area is built with `Areas.create` and its `add_vertex` and `register`
-- methods, or drawn in game with the Area Tool. Registered areas are sent to all clients
-- and saved. `Areas.contains` and `Areas.find_at` tell which areas a position is in.

mod 'Areas'

local stored = Areas.stored or {}
local callbacks = Areas.callbacks or {}
local types = Areas.types or {}
local top = Areas.top or 0
local bounds = Areas.bounds or setmetatable({}, { __mode = 'k' })
Areas.stored = stored
Areas.callbacks = callbacks
Areas.types = types
Areas.top = top
Areas.bounds = bounds

--- Returns all registered areas.
-- @return [Map area tables keyed by area id]
function Areas.all()
  return stored
end

--- Replaces all registered areas at once. Does not network anything.
-- @param stored_table [Map area tables keyed by area id; any non-table value clears
--   the areas]
function Areas.set_stored(stored_table)
  stored = (istable(stored_table) and stored_table) or {}
  Areas.stored = stored
end

--- Returns the callbacks that were set with Areas.set_callback.
-- @return [Map callback functions keyed by area type id]
function Areas.get_callbacks()
  return callbacks
end

--- Returns all registered area types.
-- @return [Map type tables (name, description, callback, color) keyed by type id]
function Areas.get_types()
  return types
end

--- Returns how many times an area has been registered through Areas.register.
-- The counter is not decreased when an area is removed.
-- @return [Number]
function Areas.get_count()
  return top
end

--- Returns all registered areas of the specified type.
-- @param type_id [String area type id]
-- @return [List list of area tables]
function Areas.get_by_type(type_id)
  local to_ret = {}

  for _, area in pairs(stored) do
    if area.type == type_id then
      to_ret[#to_ret + 1] = area
    end
  end

  return to_ret
end

--- Returns the horizontal bounding box of an area, computed once per area table.
-- @param area [Map]
-- @return [List the smallest x, the smallest y, the largest x and the largest y]
local function get_bounds(area)
  local box = bounds[area]

  if box then return box end

  local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge

  for _, poly in ipairs(area.polys) do
    for _, vertex in ipairs(poly) do
      local x, y = vertex.x, vertex.y

      min_x = math.min(min_x, x)
      min_y = math.min(min_y, y)
      max_x = math.max(max_x, x)
      max_y = math.max(max_y, y)
    end
  end

  box = { min_x, min_y, max_x, max_y }
  bounds[area] = box

  return box
end

--- Checks whether a position is inside of an area: within one of its polygons, above the
-- floor of that polygon and below the ceiling of the area. 16 units are added to the height
-- of the position, so that the position of a player's feet counts as inside.
-- @param area [Map the area]
-- @param pos [Vector position to check]
-- @return [Boolean]
function Areas.contains(area, pos)
  local polys = area.polys

  if !istable(polys) then return false end

  local box = get_bounds(area)
  local x, y = pos.x, pos.y

  if x < box[1] or x > box[3] or y < box[2] or y > box[4] then return false end

  local z = pos.z + 16
  local max_height = area.maxh

  for i = 1, #polys do
    local poly = polys[i]
    local first_vertex = poly[1]

    if first_vertex and z > first_vertex.z and z < max_height and util.vector_in_poly(pos, poly) then
      return true
    end
  end

  return false
end

--- Finds every area that a position is inside of.
-- @param pos [Vector position to check, as `Areas.contains` takes it]
-- @param type_id=nil [String only return the areas of this type; every type if nil]
-- @return [List<Map> the areas that contain the position, empty if there are none]
-- @see [Areas.contains]
function Areas.find_at(pos, type_id)
  local found = {}

  for _, area in pairs(stored) do
    if istable(area) and (type_id == nil or area.type == type_id) and Areas.contains(area, pos) then
      found[#found + 1] = area
    end
  end

  return found
end

--- The methods of the builders that Areas.create returns.
local builder = Areas.builder or {}
builder.__index = builder
Areas.builder = builder

--- Adds a vertex to the polygon currently being built. The first vertex of a polygon sets the
-- floor and the ceiling of the area, the following ones are flattened to that floor.
-- @param vect [Vector position of the vertex]
function builder:add_vertex(vect)
  local verts = self.verts
  local count = #verts

  if count == 0 then
    self.minh = vect.z
    self.maxh = self.minh + self.height
  else
    vect.z = self.minh
  end

  verts[count + 1] = vect
end

--- Stores the current vertices as a finished polygon and starts a new one.
function builder:finish_poly()
  local polys = self.polys

  polys[#polys + 1] = self.verts
  self.verts = {}
end

--- Finishes the current polygon if it has more than two vertices and registers the area.
-- A registered builder becomes the stored area, without its methods, and is not used again.
-- @return [Map the registered area, or nil if it has no polygon]
function builder:register()
  if #self.verts > 2 then self:finish_poly() end

  local area = Areas.register(self.id, setmetatable(self, nil))

  if !area then
    setmetatable(self, builder)
  end

  return area
end

--- Creates an area builder: a new area, or a copy of the already registered area with that id.
-- The stored area is not changed until the builder is registered.
-- The builder has the add_vertex(vect), finish_poly() and register() methods, and every field
-- set on it ends up in the area. The first vertex of a polygon sets the floor height, the
-- following ones are flattened to it. finish_poly() closes the current polygon and starts a
-- new one. register() closes the current polygon and passes the area to Areas.register.
-- ```
-- local area = Areas.create('town_square', 512, { type = 'textarea' })
-- area.text = 'Town Square'
--
-- area:add_vertex(Vector(0, 0, 0))
-- area:add_vertex(Vector(512, 0, 0))
-- area:add_vertex(Vector(512, 512, 0))
--
-- -- Optional: start another polygon within the same area.
-- area:finish_poly()
--
-- area:add_vertex(Vector(1024, 0, 0))
-- area:add_vertex(Vector(1536, 0, 0))
-- area:add_vertex(Vector(1536, 512, 0))
--
-- area:register()
-- ```
-- @param id [String unique area id]
-- @param height=0 [Number height of the area above its first vertex; an existing area keeps
--   its own]
-- @param data=nil [Map extra fields to merge into a new area, e.g. { type = 'textarea' }.
--   The type defaults to 'area']
-- @return [Map the area builder]
-- @see [Areas.register]
function Areas.create(id, height, data)
  local existing = stored[id]
  local area

  if existing then
    area = table.Copy(existing)
    area.id = id
    area.verts = {}
  else
    data = data or {}
    area = {
      id = id,
      minh = 0,
      maxh = 0,
      height = height or 0,
      verts = {},
      polys = {},
      type = data.type or 'area'
    }

    table.Merge(area, data)
  end

  return setmetatable(area, builder)
end

--- Stores the area under the given id, stripping any functions from it.
-- When called on the server the area is also sent to all clients and saved.
-- @param id [String unique area id]
-- @param data [Map area table as built by Areas.create; needs at least one polygon]
-- @return [Map the stored area, or nil if an argument is missing or the area has no
--   polygons]
-- @see [Areas.create]
function Areas.register(id, data)
  if !id or !data then return end

  if !istable(data.polys) or #data.polys < 1 then
    Flux.dev_print("Area '"..tostring(id).."' has no polygon with three vertices and is not registered.")

    return
  end

  data = table.remove_functions(data)

  stored[id] = data

  top += 1
  Areas.top = top

  if SERVER then
    Cable.send(nil, 'fl_area_register', id, data)
    Areas.save()
  end

  return stored[id]
end

--- Removes the area with the given id.
-- When called on the server, the players inside of the area leave it first, then the removal
-- is sent to all clients and saved.
-- @param id [String area id]
function Areas.remove(id)
  if SERVER and stored[id] then
    Areas.leave_area(id, stored[id])
  end

  stored[id] = nil

  if SERVER then
    Cable.send(nil, 'fl_area_remove', id)
    Areas.save()
  end
end

--- Returns the color that is used to draw areas of the specified type in the area tool.
-- @param type_id [String area type id]
-- @return [Color the color of the type, or nil if the type is not registered]
function Areas.get_color(type_id)
  local type_table = types[type_id]

  if istable(type_table) then
    return type_table.color
  end
end

--- Registers an area type along with the callback that runs when a player enters
-- or leaves an area of that type. The callback runs on the server for every player
-- and on the client for the local player.
-- ```
-- Areas.register_type(
--   'safezone',
--   'Safe Zone',
--   'Notifies other plugins when a player enters or leaves the zone.',
--   Color(0, 255, 0),
--   function(actor, area, has_entered, pos, cur_time)
--     if has_entered then
--       hook.Run('PlayerEnteredSafeZone', actor, area, cur_time)
--     else
--       hook.Run('PlayerLeftSafeZone', actor, area, cur_time)
--     end
--   end
-- )
-- ```
-- @param id [String unique type id]
-- @param name [String human-readable name of the type]
-- @param description [String]
-- @param color=Color(255, 0, 255) [Color the color of the areas in the area tool]
-- @param default_callback=nil [Function called as callback(actor, area, has_entered,
--   pos, cur_time) unless overridden with Areas.set_callback]
-- @see [Areas.set_callback]
function Areas.register_type(id, name, description, color, default_callback)
  types[id] = {
    name = name,
    description = description,
    callback = default_callback,
    color = color or Color(255, 0, 255)
  }
end

--- Overrides the enter / leave callback for the specified area type.
-- The callback takes priority over the default callback of the type.
-- @param area_type [String area type id]
-- @param callback [Function called as callback(actor, area, has_entered, pos, cur_time)]
-- @see [Areas.register_type]
function Areas.set_callback(area_type, callback)
  callbacks[area_type] = callback
end

--- Returns the enter / leave callback of the specified area type.
-- @param area_type [String area type id]
-- @return [Function the callback set with Areas.set_callback, else the default callback
--   of the type, else a stub that prints a developer warning]
function Areas.get_callback(area_type)
  return callbacks[area_type] or (types[area_type] and types[area_type].callback) or
    function() Flux.dev_print("Callback for area type '"..area_type.."' could not be found!") end
end

Areas.register_type(
  'area',
  'Simple Area',
  'A simple area. Use this type if you have a callback somewhere in the code that looks up id instead of type ID.',
  Color(255, 0, 255),
  function(actor, area, has_entered, _pos, cur_time)
    if has_entered then
      --- Called when a player enters an area of the `area` type. Runs on the server and on
      -- the client of that player.
      -- @param actor [Player The player who has entered the area]
      -- @param area [Map The area table]
      -- @param cur_time [Number CurTime() of the check]
      hook.Run('PlayerEnteredArea', actor, area, cur_time)
    else
      --- Called when a player leaves an area of the `area` type. Runs on the server and on
      -- the client of that player.
      -- @param actor [Player The player who has left the area]
      -- @param area [Map The area table]
      -- @param cur_time [Number CurTime() of the check]
      hook.Run('PlayerLeftArea', actor, area, cur_time)
    end
  end
)
