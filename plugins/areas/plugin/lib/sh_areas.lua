mod 'Areas'

local stored = Areas.stored or {}
local callbacks = Areas.callbacks or {}
local types = Areas.types or {}
local top = Areas.top or 0
Areas.stored = stored
Areas.callbacks = callbacks
Areas.types = types
Areas.top = top

function Areas.all()
  return stored
end

function Areas.set_stored(stored_table)
  stored = (istable(stored_table) and stored_table) or {}
end

function Areas.get_callbacks()
  return callbacks
end

function Areas.get_types()
  return types
end

function Areas.get_count()
  return top
end

function Areas.get_by_type(type)
  local to_ret = {}

  for k, v in pairs(stored) do
    if v.type == type then
      table.insert(to_ret, v)
    end
  end

  return to_ret
end

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

    return Areas.register(id, self)
  end

  return area
end

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

function Areas.remove(id)
  stored[id] = nil

  if SERVER then
    Cable.send(nil, 'fl_area_remove', id)
  end
end

function Areas.get_color(type_id)
  local type_table = types[type_id]

  if istable(type_table) then
    return type_table.color
  end
end

function Areas.register_type(id, name, description, color, default_callback)
  types[id] = {
    name = name,
    description = description,
    callback = default_callback,
    color = color or Color(255, 0, 255)
  }
end

-- callback(player, area, poly, has_entered, cur_pos, cur_time)
function Areas.set_callback(area_type, callback)
  callbacks[area_type] = callback
end

function Areas.get_callback(area_type)
  return callbacks[area_type] or (types[area_type] and types[area_type].callback) or function() Flux.dev_print("Callback for area type '"..area_type.."' could not be found!") end
end

Areas.register_type(
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
