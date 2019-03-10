library 'areas'

local stored = areas.stored or {}
local callbacks = areas.callbacks or {}
local types = areas.types or {}
local top = areas.top or 0
areas.stored = stored
areas.callbacks = callbacks
areas.types = types
areas.top = top

function areas.all()
  return stored
end

function areas.set_stored(stored_table)
  stored = (istable(stored_table) and stored_table) or {}
end

function areas.get_callbacks()
  return callbacks
end

function areas.get_types()
  return types
end

function areas.get_count()
  return top
end

function areas.get_by_type(type)
  local to_ret = {}

  for k, v in pairs(stored) do
    if v.type == type then
      table.insert(to_ret, v)
    end
  end

  return to_ret
end

function areas.create(id, height, data)
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
      table.merge(area, data)
    end
  else
    area = stored[id]
  end

  function area:add_vertex(vect)
    if #self.verts == 0 then
      self.minh = vect.z
      self.maxh = self.minh + self.height
    else
      vect.z = self.minh
    end

    table.insert(self.verts, vect)
  end

  function area:finish_poly()
    table.insert(self.polys, self.verts)
    self.verts = {}
  end

  function area:register()
    if #self.verts > 2 then self:finish_poly() end

    return areas.register(id, self)
  end

  return area
end

function areas.register(id, data)
  if !id or !data then return end
  if #data.polys < 1 then return end

  data = table.remove_functions(data)

  stored[id] = data

  top = top + 1

  if SERVER then
    cable.send(nil, 'fl_area_register', id, data)
  end

  return stored[id]
end

function areas.remove(id)
  stored[id] = nil

  if SERVER then
    cable.send(nil, 'fl_area_remove', id)
  end
end

function areas.get_color(typeID)
  local type_table = types[typeID]

  if istable(type_table) then
    return type_table.color
  end
end

function areas.register_type(id, name, description, color, default_callback)
  types[id] = {
    name = name,
    description = description,
    callback = default_callback,
    color = color or Color(255, 0, 255)
  }
end

-- callback(player, area, poly, has_entered, cur_pos, cur_time)
function areas.set_callback(area_type, callback)
  callbacks[area_type] = callback
end

function areas.get_callback(area_type)
  return callbacks[area_type] or (types[area_type] and types[area_type].callback) or function() Flux.dev_print("Callback for area type '"..area_type.."' could not be found!") end
end

areas.register_type(
  'area',
  'Simple Area',
  'A simple area. Use this type if you have a callback somewhere in the code that looks up id instead of type ID.',
  function(player, area, poly, has_entered, cur_pos, cur_time)
    if has_entered then
      hook.run('PlayerEnteredArea', player, area, cur_time)
    else
      hook.run('PlayerLeftArea', player, area, cur_time)
    end
  end
)
