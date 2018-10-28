library.new 'areas'

local stored = areas.stored or {}
areas.stored = stored

local callbacks = areas.callbacks or {}
areas.callbacks = callbacks

local types = areas.types or {}
areas.types = types

local top = areas.top or 0
areas.top = top

function areas.GetAll()
  return stored
end

function areas.SetStored(stored_table)
  stored = (istable(stored_table) and stored_table) or {}
end

function areas.GetCallbacks()
  return callbacks
end

function areas.GetTypes()
  return types
end

function areas.GetCount()
  return top
end

function areas.GetByType(type)
  local to_ret = {}

  for k, v in pairs(stored) do
    if v.type == type then
      table.insert(to_ret, v)
    end
  end

  return to_ret
end

function areas.Create(id, height, data)
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

  function area:AddVertex(vect)
    if #self.verts == 0 then
      self.minh = vect.z
      self.maxh = self.minh + self.height
    else
      vect.z = self.minh
    end

    table.insert(self.verts, vect)
  end

  function area:FinishPoly()
    table.insert(self.polys, self.verts)
    self.verts = {}
  end

  function area:register()
    if #self.verts > 2 then self:FinishPoly() end

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
    cable.send(nil, 'flAreaRegister', id, data)
  end

  return stored[id]
end

function areas.Remove(id)
  stored[id] = nil

  if SERVER then
    cable.send(nil, 'flAreaRemove', id)
  end
end

function areas.GetColor(typeID)
  local type_table = types[typeID]

  if istable(type_table) then
    return type_table.color
  end
end

function areas.RegisterType(id, name, description, color, default_callback)
  types[id] = {
    name = name,
    description = description,
    callback = default_callback,
    color = color or Color(255, 0, 255)
  }
end

-- callback(player, area, poly, has_entered, cur_pos, cur_time)
function areas.SetCallback(area_type, callback)
  callbacks[area_type] = callback
end

function areas.GetCallback(area_type)
  return callbacks[area_type] or (types[area_type] and types[area_type].callback) or function() fl.dev_print("Callback for area type '"..area_type.."' could not be found!") end
end

areas.RegisterType(
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
