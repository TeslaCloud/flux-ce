class 'ActiveRecord::Relation'

ActiveRecord.Relation.objects = {}
ActiveRecord.Relation.class = nil

function ActiveRecord.Relation:init(object, class)
  self.object = class.new()
  self.object_class = class
  self.object.fetched = true

  local schema = ActiveRecord.schema[class.table_name]

  for k, v in pairs(object) do
    self.object[k] = ActiveRecord.str_to_type(v, schema[k] or 'string')
  end

  if isfunction(self.object.restored) then
    self.object:restored()
  end
end

function ActiveRecord.Relation:update_attribute(key, value)
  for k, v in ipairs(self.object) do
    v[key] = value
    v:save()
  end
  return self
end

function ActiveRecord.Relation:destroy(id)
  local id = id or 1
  local obj = self.object[id]
  if IsValid(obj) and !obj.static_class then
    obj:destroy()
  end
  return self
end

function ActiveRecord.Relation:destroy_all()
  for k, v in ipairs(self.object) do
    self:destroy(k)
  end
  return self
end

function ActiveRecord.Relation:__tostring()
  return 'ActiveRecord::Relation #<'..table.concat(table.map_kv(self.object, function(k, v)
    if isfunction(v) then return end
    if istable(v) then return end

    if isstring(v) then
      return tostring(k)..': "'..v:sub(1, 64)..'"'
    else
      return tostring(k)..': '..tostring(v)
    end
  end), ', ')..'>'
end
