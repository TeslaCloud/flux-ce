library.new "areas"

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

function areas.SetStored(storedTable)
  stored = (istable(storedTable) and storedTable) or {}
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
    area.minH = 0
    area.maxH = 0
    area.height = height or 0
    area.verts = {}
    area.polys = {}
    area.type = data.type or "area"

    if data then
      table.merge(area, data)
    end
  else
    area = stored[id]
  end

  function area:AddVertex(vect)
    if #self.verts == 0 then
      self.minH = vect.z
      self.maxH = self.minH + self.height
    else
      vect.z = self.minH
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

  data = util.remove_functions(data)

  stored[id] = data

  top = top + 1

  if SERVER then
    netstream.Start(nil, "flAreaRegister", id, data)
  end

  return stored[id]
end

function areas.Remove(id)
  stored[id] = nil

  if SERVER then
    netstream.Start(nil, "flAreaRemove", id)
  end
end

function areas.GetColor(typeID)
  local typeTable = types[typeID]

  if istable(typeTable) then
    return typeTable.color
  end
end

function areas.RegisterType(id, name, description, color, defaultCallback)
  types[id] = {
    name = name,
    description = description,
    callback = defaultCallback,
    color = color or Color(255, 0, 255)
  }
end

-- callback(player, area, poly, bHasEntered, curPos, curTime)
function areas.SetCallback(areaType, callback)
  callbacks[areaType] = callback
end

function areas.GetCallback(areaType)
  return callbacks[areaType] or (types[areaType] and types[areaType].callback) or function() fl.dev_print("Callback for area type '"..areaType.."' could not be found!") end
end

areas.RegisterType(
  "area",
  "Simple Area",
  "A simple area. Use this type if you have a callback somewhere in the code that looks up id instead of type ID.",
  function(player, area, poly, bHasEntered, curPos, curTime)
    if bHasEntered then
      hook.run("PlayerEnteredArea", player, area, curTime)
    else
      hook.run("PlayerLeftArea", player, area, curTime)
    end
  end
)
