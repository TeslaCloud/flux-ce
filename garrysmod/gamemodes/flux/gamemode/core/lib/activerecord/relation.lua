class 'ActiveRecord::Relation'

ActiveRecord.Relation.objects = {}
ActiveRecord.Relation.class = nil

function ActiveRecord.Relation:init(objects, class)
  self.objects = {}
  self.object_class = class

  for _, res in ipairs(objects) do
    local obj = class.new()
      obj.fetched = true
      for k, v in pairs(res) do
        obj[k] = v
      end
    table.insert(self.objects, obj)
  end
end

function ActiveRecord.Relation:update_attribute(key, value)
  for k, v in ipairs(self.objects) do
    v[key] = value
    v:save()
  end
  return self
end

function ActiveRecord.Relation:first()
  return self.objects[1]
end

function ActiveRecord.Relation:destroy(id)
  local id = id or 1
  local obj = self.objects[id]
  if IsValid(obj) and !obj.static_class then
    obj:destroy()
  end
  return self
end

function ActiveRecord.Relation:destroy_all()
  for k, v in ipairs(self.objects) do
    self:destroy(k)
  end
  return self
end

function ActiveRecord.Relation:__index(key)
  return self.objects[1] and self.objects[1][key]
end

function ActiveRecord.Relation:__tostring()
  return 'ActiveRecord::Relation #<'..table.concat(table.map_kv(self.objects, function(k, v)
    if isstring(v) then
      return tostring(k)..': "'..v:sub(1, 64)..'"'
    else
      return tostring(k)..': '..tostring(v)
    end
  end), ', ')..'>'
end
