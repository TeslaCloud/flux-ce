class 'ActiveRecord::Base'

ActiveRecord.Base.query_map = a{}
ActiveRecord.Base.table_name = ''
ActiveRecord.Base.schema = {}

function ActiveRecord.Base:init()
  self.fetched = false
end

function ActiveRecord.Base:class_extended(base_class, new_class)
  new_class.table_name = ActiveRecord.pluralize(new_class.class_name:to_snake_case())
  ActiveRecord.Model:add(new_class)
end

function ActiveRecord.Base:where(condition, ...)
  local args = {...}
  local query_str = ''

  if #args > 0 then
    local n = 0

    query_str = condition:gsub('%?', function()
      n = n + 1
      return "'"..ActiveRecord.adapter:escape(tostring(args[n])).."'"
    end)
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

function ActiveRecord.Base:order(column, direction)
  self.query_map:insert { 'order', column, direction }
  return self
end

function ActiveRecord.Base:find(condition)
  return self
end

function ActiveRecord.Base:limit(amt)
  self.query_map:insert { 'limit', amt }
  return self
end

function ActiveRecord.Base:run_query(callback)
  self.query_map = a{}
end

function ActiveRecord.Base:expect(callback)
  self:run_query(function(results)
    if istable(results) and #results > 0 then
      callback(results[1])
    end
  end)
end

function ActiveRecord.Base:get(callback)
  self:run_query(function(results)
    if istable(results) and #results > 0 then
      callback(results)
    end
  end)
end

function ActiveRecord.Base:save()
  local schema = ActiveRecord.schema[self.table_name]

  if !schema then return end
  if !self.fetched then
    local query = ActiveRecord.Database:insert(self.table_name)
      for k, v in pairs(schema) do
        query:insert(k, self[k])
      end
      query:insert('created_at', to_datetime(os.time()))
      query:insert('updated_at', to_datetime(os.time()))
    query:execute()
  else
    local query = ActiveRecord.Database:update(self.table_name)
      for k, v in pairs(schema) do
        query:update(k, self[k])
      end
      query:update('updated_at', to_datetime(os.time()))
    query:execute()
  end
end
