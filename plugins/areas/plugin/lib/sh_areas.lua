mod 'Areas'

local stored = Areas.stored or {}
local callbacks = Areas.callbacks or {}
local types = Areas.types or {}
local top = Areas.top or 0
Areas.stored = stored
Areas.callbacks = callbacks
Areas.types = types
Areas.top = top

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
-- @param type [String area type id]
-- @return [List list of area tables]
function Areas.get_by_type(type)
  local to_ret = {}

  for k, v in pairs(stored) do
    if v.type == type then
      table.insert(to_ret, v)
    end
  end

  return to_ret
end

--- Creates an area builder, or fetches the already registered area with that id.
-- The returned table gains add_vertex(vect), finish_poly() and register() methods.
-- The first vertex of a polygon sets the floor height, the following ones are flattened
-- to it. finish_poly() closes the current polygon and starts a new one.
-- register() closes the current polygon and passes the area to Areas.register.
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
-- @param height=0 [Number height of the area above its first vertex]
-- @param data=nil [Map extra fields to merge into a new area, e.g. { type = 'textarea' }.
--   The type defaults to 'area']
-- @return [Map the area table with the builder methods]
-- @see [Areas.register]
function Areas.create(id, height, data)
  data = data or {}

  local area = {}

  if !stored[id] then
    area.id = id
    area.minh = 0
    area.maxh = 0
    area.height = height or 0
    area.verts = {}
    area.polys = {}
    area.type = data.type or 'area'

    if data then
      table.Merge(area, data)
    end
  else
    area = stored[id]
  end

  --- Adds a vertex to the polygon currently being built. The first vertex sets the
  -- area's base height, subsequent vertices are snapped to it.
  -- @param vect [Vector position of the vertex]
  function area:add_vertex(vect)
    if #self.verts == 0 then
      self.minh = vect.z
      self.maxh = self.minh + self.height
    else
      vect.z = self.minh
    end

    table.insert(self.verts, vect)
  end

  --- Stores the current vertices as a finished polygon and starts a new one.
  function area:finish_poly()
    table.insert(self.polys, self.verts)
    self.verts = {}
  end

  --- Finishes the current polygon if it has more than two vertices and registers the area.
  -- @return [Map the registered area]
  function area:register()
    if #self.verts > 2 then self:finish_poly() end

    return Areas.register(id, self)
  end

  return area
end

--- Stores the area under the given id, stripping any functions from it.
-- When called on the server the area is also sent to all clients.
-- @param id [String unique area id]
-- @param data [Map area table as built by Areas.create; needs at least one polygon]
-- @return [Map the stored area, or nil if an argument is missing or the area has no
--   polygons]
-- @see [Areas.create]
function Areas.register(id, data)
  if !id or !data then return end
  if #data.polys < 1 then return end

  data = table.remove_functions(data)

  stored[id] = data

  top = top + 1

  if SERVER then
    Cable.send(nil, 'fl_area_register', id, data)
  end

  return stored[id]
end

--- Removes the area with the given id.
-- When called on the server the removal is also sent to all clients.
-- @param id [String area id]
function Areas.remove(id)
  stored[id] = nil

  if SERVER then
    Cable.send(nil, 'fl_area_remove', id)
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
  function(actor, area, has_entered, pos, cur_time)
    if has_entered then
      hook.Run('PlayerEnteredArea', actor, area, cur_time)
    else
      hook.Run('PlayerLeftArea', actor, area, cur_time)
    end
  end
)
