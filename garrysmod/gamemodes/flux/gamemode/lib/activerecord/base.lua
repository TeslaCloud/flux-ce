class 'ActiveRecord::Base'

ActiveRecord.Base.query_map = a{}
ActiveRecord.Base.table_name = ''
ActiveRecord.Base.schema = nil
ActiveRecord.Base.relations = {}

function ActiveRecord.Base:init()
  self.fetched = false
  self.saving = false
end

function ActiveRecord.Base:class_extended(new_class)
  new_class.table_name = ActiveRecord.Infector:pluralize(new_class.class_name:to_snake_case())
  ActiveRecord.Model:add(new_class)
end

function ActiveRecord.Base:get_schema()
  self.schema = self.schema or ActiveRecord.schema[self.table_name] or {}
  return self.schema
end

-- Dump object as a simple data table.
function ActiveRecord.Base:dump()
  local ret = {}
    for k, v in pairs(self:get_schema()) do
      ret[k] = self[k]
    end
  return ret, self
end

-- Basic querying
function ActiveRecord.Base:where(condition, ...)
  local args = {...}
  local query_str = ''

  if #args > 0 then
    if condition:find('[=<>]') then
      local n = 0

      query_str = condition:gsub('%?', function()
        n = n + 1
        return "'"..ActiveRecord.adapter:escape(tostring(args[n])).."'"
      end)
    else
      query_str = condition..' = \''..ActiveRecord.adapter:escape(tostring(args[1]))..'\''
    end
  elseif istable(condition) then
    local should_and = false
    for k, v in pairs(condition) do
      query_str = query_str..(should_and and ' AND ' or '')..k
      if !istable(v) then
        query_str = query_str..' = \''..ActiveRecord.adapter:escape(tostring(v))..'\''
      else
        v = table.map(v, function(t) return "'"..ActiveRecord.adapter:escape(tostring(t)).."'" end)
        query_str = query_str..' IN ('..table.concat(v, ', ')..')'
      end
      should_and = true
    end
  end

  self.query_map:insert { 'where', query_str }

  return self
end

function ActiveRecord.Base:where_not(condition, ...)
  local args = {...}
  local query_str = ''

  if #args > 0 then
    local n = 0

    query_str = 'NOT ('..condition:gsub('%?', function()
      n = n + 1
      return "'"..ActiveRecord.adapter:escape(tostring(args[n])).."'"
    end)..')'
  elseif istable(condition) then
    local should_and = false
    for k, v in pairs(condition) do
      query_str = query_str..(should_and and ' AND ' or '')..k
      if !istable(v) then
        query_str = query_str..' != \''..ActiveRecord.adapter:escape(tostring(v))..'\''
      else
        v = table.map(v, function(t) return "'"..ActiveRecord.adapter:escape(tostring(t)).."'" end)
        query_str = query_str..' NOT IN ('..table.concat(v, ', ')..')'
      end
      should_and = true
    end
  end

  self.query_map:insert { 'where', query_str }

  return self
end

function ActiveRecord.Base:first()
  return self:order('id'):limit(1)
end

function ActiveRecord.Base:last()
  return self:order('id', 'desc'):limit(1)
end

function ActiveRecord.Base:all()
  return self:order('id')
end

function ActiveRecord.Base:order(column, direction)
  self.query_map:insert { 'order', column, direction }
  return self
end

function ActiveRecord.Base:find(id, callback)
  if !callback then
    return self:where('id', id):limit(1)
  else
    return self:find(id):expect(callback)
  end
end

function ActiveRecord.Base:find_by(column, value, callback)
  if !callback then
    return self:where(column, value):limit(1)
  else
    return self:find_by(column, value):expect(callback)
  end
end

function ActiveRecord.Base:limit(amt)
  self.query_map:insert { 'limit', amt }
  return self
end

function ActiveRecord.Base:_process_child(obj, target_class)
  local should_stop = false
  if isfunction(self.as_child) then
    should_stop = self:as_child(obj, target_class)
  end
  if isfunction(obj.as_parent) then
    should_stop = obj:as_parent(self, self.class)
  end
  if !should_stop then
    for k, v in ipairs(self.relations) do
      if v.child and v.target_class == target_class then
        self[v.as] = obj
        break
      end
    end
  end
  return self
end

-- internal
function ActiveRecord.Base:_fetch_relation(callback, objects, n, obj_id)
  n = n or 1
  obj_id = obj_id or 1

  local current_object = objects[obj_id].object
  local relation = self.relations[n]
  
  if relation then
    if !relation.child then
      local obj = relation.model:where(relation.column_name, current_object.id)
      if relation.many then
        obj:rescue(function()
          return self:_fetch_relation(callback, objects, n + 1, obj_id)
        end):get(function(res)
          current_object[relation.as] = {}
          for k, v in ipairs(res) do
            v:_process_child(current_object, current_object.class)
            table.insert(current_object[relation.as], v)
          end
          return self:_fetch_relation(callback, objects, n + 1, obj_id)
        end)
      else
        obj:first():rescue(function()
          return self:_fetch_relation(callback, objects, n + 1, obj_id)
        end):expect(function(res)
          res:_process_child(current_object, current_object.class)
          current_object[relation.as] = res
          return self:_fetch_relation(callback, objects, n + 1, obj_id)
        end)
      end
    else
      return self:_fetch_relation(callback, objects, n + 1, obj_id)
    end
  else
    if #objects > obj_id then
      self:_fetch_relation(callback, objects, 1, obj_id + 1) -- reset relation counter
    else
      callback(objects) -- finally able to callback
    end
  end
  return self
end

function ActiveRecord.Base:run_query(callback)
  if self.query_map and #self.query_map > 0 then
    local query = ActiveRecord.Database:select(self.table_name)
    for k, v in ipairs(self.query_map) do
      local t, a, b = v[1], v[2], v[3]

      if t == 'where' then
        query:where_raw(a)
      elseif t == 'order' then
        if b then
          query:order({ [b] = a })
        else
          query:order(a)
        end
      elseif t == 'limit' then
        query:limit(a)
      end
    end
    self.query_map = a{}
    query:callback(function(results, query, time)
      print_query(self.class_name..' Load ('..time..'ms)', query)
      if istable(results) and #results > 0 then
        local objects = {}

        for k, v in ipairs(results) do
          table.insert(objects, ActiveRecord.Relation.new(v, self.class))
        end

        if #self.relations == 0 then
          return callback(objects)
        else
          return self:_fetch_relation(callback, objects)
        end
      elseif isfunction(self._rescue) then
        self._rescue(self.class.new())
        self._rescue = nil
        if isfunction(self.created) then
          self:created()
        end
      end
    end)
    query:execute()
  end
  return self
end

function ActiveRecord.Base:expect(callback)
  return self:run_query(function(results)
    callback(results[1].object)
  end)
end

function ActiveRecord.Base:get(callback)
  return self:run_query(function(results)
    local all_objects = {}

    for k, v in ipairs(results) do
      table.insert(all_objects, v.object)
    end

    callback(all_objects)
  end)
end

function ActiveRecord.Base:rescue(callback)
  self._rescue = callback
  return self
end

local except = {
  id = true, created_at = true, updated_at = true
}

function ActiveRecord.Base:save()
  local schema = self:get_schema()

  if !schema or self.saving then return self end

  self.saving = true

  if !self.fetched then
    self.fetched = true

    local query = ActiveRecord.Database:insert(self.table_name)
      for k, v in pairs(schema) do
        if except[k] then continue end
        query:insert(k, self[k])
      end
      query:insert('created_at', to_datetime(os.time()))
      query:insert('updated_at', to_datetime(os.time()))
      query:callback(function(result, query, time)
        print_query(self.class_name..' Create ('..time..'ms)', query)
        self.saving = false
      end)
    query:execute()
  else
    local query = ActiveRecord.Database:update(self.table_name)
      query:where('id', self.id)
      for k, v in pairs(schema) do
        if except[k] then continue end
        query:update(k, self[k])
      end
      query:update('updated_at', to_datetime(os.time()))
      query:callback(function(result, query, time)
        print_query(self.class_name..' Update ('..time..'ms)', query)
        self.saving = false
      end)
    query:execute()
  end
  if #self.relations > 0 then
    for _, relation in ipairs(self.relations) do
      if !relation.child then
        if relation.many and istable(self[relation.as]) then
          for k, v in ipairs(self[relation.as]) do
            v:save()
          end
        elseif !relation.many and istable(self[relation.as]) then
          local rel = self[relation.as]
          if IsValid(rel) and isfunction(rel.save) then
            self[relation.as]:save()
          end
        end
      end
    end
  end
  return self
end

function ActiveRecord.Base:destroy()
  local query = ActiveRecord.Database:delete(self.table_name)
    query:where('id', self.id)
    query:callback(function(result, query, time)
      print_query(self.class_name..' Delete ('..time..'ms)', query)
    end)
  query:execute()
  self = nil
end

-- ActiveRecord relations
function ActiveRecord.Base:has(what, many)
  local relation = {}
    local table_name = ''
    local should_add = true
    relation.child = false
    if istable(what) then
      table_name = what[1]:to_snake_case()
      relation.as = what.as or table_name
    elseif isstring(what) then
      table_name = what
      relation.as = table_name
    end
    if self.relations[table_name] then
      relation = self.relations[self.relations[table_name]]
      -- has_one has higher priority over has_many
      if !many then
        relation.many = false
      end
      should_add = false
    else
      relation.many = many
    end
    for k, v in pairs(ActiveRecord.Model:all()) do
      if v.table_name == table_name then
        relation.model = v
        break
      end
    end
    relation.table_name = table_name
    relation.column_name = self.class_name:to_snake_case()..'_id'
    if should_add then
      local index = table.insert(self.relations, relation)
      self.relations[table_name] = index
    end
  return self
end

function ActiveRecord.Base:has_many(what)
  return self:has(what, true)
end

function ActiveRecord.Base:has_one(what)
  return self:has({ ActiveRecord.Infector:pluralize(what), as = what }, false)
end

function ActiveRecord.Base:belongs_to(target, one)
  if isstring(target) then
    target = target:parse_table()
  end
  if istable(target) then
    target:has(self.table_name, !one)
    table.insert(self.relations, {
      child = true,
      as = target.class_name:to_snake_case(),
      target_class = target
    })
  end
end
