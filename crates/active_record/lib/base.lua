--- Base class for ActiveRecord database-tied objects.
-- These objects are also referred to as "models".
class 'ActiveRecord::Base'

--- @warning [Internal]
-- Provides backend data storage for the querying engine.
-- @return [MetaArray]
ActiveRecord.Base.query_map   = a{}

--- Database table the object is tied to.
-- @return [String]
ActiveRecord.Base.table_name  = ''

--- Database schema of the object.
-- This table contains all the columns that are written to the database.
-- @return [Hash]
ActiveRecord.Base.schema      = nil

--- @warning [Internal]
-- Class relations of the object.
-- Serves as a list of objects that are children to this object
-- or that this object is a child to.
-- @return [Hash]
ActiveRecord.Base.relations   = {}

--- @warning [Internal]
-- List of validations to be ran when the object is being saved,
-- as well as some internal data related to them.
-- @return [Hash]
ActiveRecord.Base.validations = {}

--- @warning [Internal]
-- Sets up basic variables and creates empty tables for
-- relations that the object has many of.
function ActiveRecord.Base:init()
  self.fetched = false
  self.saving = false

  for k, v in ipairs(self.relations) do
    if !self[v.table_name] and v.many then
      self[v.table_name] = {}
    end
  end
end

--- @warning [Internal]
-- When the ActiveRecord::Base class is extended,
-- the new model is added to the global models list,
-- and it's table name is determined based on the class name.
-- Make sure you create a table that is named as a lowercase plural
-- of the class name, or else this will fail!
function ActiveRecord.Base:class_extended(new_class)
  new_class.table_name = Flow.Inflector:pluralize(new_class.class_name:underscore())

  ActiveRecord.Model:add(new_class)
end

--- Returns the database schema, or attempts to get it from the global schema
-- storage in case the object hasn't been properly initialized yet.
-- @return [Hash schema]
function ActiveRecord.Base:get_schema()
  self.schema = self.schema or ActiveRecord.schema[self.table_name] or {}
  return self.schema
end

--- Dump object as a simple data table.
-- This simply dumps all the values of the variables defined in the schema.
-- @return [Hash schema, ActiveRecord::Base(self)]
function ActiveRecord.Base:dump()
  local ret = {}
    for k, data in pairs(self:get_schema()) do
      ret[k] = self[k]
    end
  return ret, self
end

--- @category [Query Engine]
-- Provides utility functions for abstracted database querying.

--- Specifies a WHERE condition in the query.
-- ```
-- Object:where('column', 'value')
-- Object:where('column > ?', 100)
-- Object:where({ ['column'] = 'value', ['column2'] = { 'value', 'value2' } })
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:where(condition, ...)
  local args = { ... }
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

--- Specifies a WHERE NOT condition in the query.
-- Works exactly the same as #where, except that it does the opposite.
-- ```
-- Object:where_not('column', 'value')
-- Object:where_not('column > ?', 100)
-- Object:where_not({ ['column'] = 'value', ['column2'] = { 'value', 'value2' } })
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:where_not(condition, ...)
  local args = { ... }
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

--- Returns the first object stored in the database.
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:first()
  return self:order('id'):limit(1)
end

--- Returns the last object stored in the database.
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:last()
  return self:order('id', 'desc'):limit(1)
end

--- Returns all of the objects stored in the database.
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:all()
  return self:order('id')
end

--- Inserts an ORDER BY condition into the query.
-- ```
-- Object:order('id', 'asc')
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:order(column, direction)
  self.query_map:insert { 'order', column, direction }
  return self
end

--- Finds an object in the database by it's ID.
-- Optionally can also call a callback right away.
-- ```
-- Object:find(1)
-- Object:find(1, function(obj) ... end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:find(id, callback)
  if !callback then
    return self:where('id', id):limit(1)
  else
    return self:find(id):expect(callback)
  end
end

--- Finds an object in the database by a column value.
-- Optionally can also call a callback right away.
-- ```
-- Object:find_by('id', 1)
-- Object:find_by('id', 1, function(obj) ... end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:find_by(column, value, callback)
  if !callback then
    return self:where(column, value):limit(1)
  else
    return self:find_by(column, value):expect(callback)
  end
end

--- Inserts a LIMIT condition into the query.
-- The code in the example below will find the first 10 entries
-- that have more than "100" money.
-- ```
-- Object:where('money > 100'):limit(10)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:limit(amt)
  self.query_map:insert { 'limit', amt }
  return self
end

--- @warning [Internal]
-- Internal function to process child objects or current object as a child to another object.
-- @return [ActiveRecord::Base(self)]
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

--- @warning [Internal]
-- Internal function to fetch all relations when the object is fetched from the database.
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:_fetch_relation(callback, objects, n, obj_id)
  n = n or 1
  obj_id = obj_id or 1

  local current_object = objects[obj_id].object
  local relation = self.relations[n]

  if relation then
    if !relation.child then
      if !relation.model then
        error_with_traceback('Relation has no model! ('..tostring(relation.table_name)..')')
        return
      end
      local obj = relation.model:where(relation.column_name, current_object.id)
      if relation.many then
        obj:get(function(res)
          current_object[relation.as] = {}
          for k, v in ipairs(res) do
            v:_process_child(current_object, current_object.class)
            table.insert(current_object[relation.as], v)
          end
          return self:_fetch_relation(callback, objects, n + 1, obj_id)
        end):rescue(function()
          current_object[relation.as] = {}
          return self:_fetch_relation(callback, objects, n + 1, obj_id)
        end)
      else
        obj:first():expect(function(res)
          res:_process_child(current_object, current_object.class)
          current_object[relation.as] = res
          return self:_fetch_relation(callback, objects, n + 1, obj_id)
        end):rescue(function()
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

--- @warning [Internal]
-- Runs current query based on the query map and flushes query map.
-- @return [ActiveRecord::Base(self)]
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
      print_query(self.class_name..' Load ('..time..'s)', query)
      if istable(results) and #results > 0 then
        local objects = {}

        for k, v in ipairs(results) do
          table.insert(objects, self:_create_restored(v))
        end

        if #self.relations == 0 then
          return callback(objects)
        else
          ar_add_indent()
          local ret = self:_fetch_relation(callback, objects)
          ar_sub_indent()
          return ret
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

--- @warning [Internal]
-- Internal function to create a new instance of object based on the
-- data from the database.
-- @return [ActiveRecord::Base(object)]
function ActiveRecord.Base:_create_restored(data)
  local object = self.class.new()
  object.id = data.id
  object.fetched = true

  local schema = ActiveRecord.schema[self.table_name]

  for k, v in pairs(data) do
    object[k] = ActiveRecord.str_to_type(v, schema[k] and schema[k].type or 'string')
  end

  if isfunction(object.restored) then
    object:restored()
  end

  return object
end

--- Used when a single return value is expected.
-- Calls the callback with a single object when the object has
-- finished loading from the database.
-- ```
-- Object:first():expect(function(obj) ... end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:expect(callback)
  self._get = nil
  self._expect = function(results)
    callback(results[1].object)
  end
  return self
end

--- Used when multiple return values are expected.
-- Calls the callback with all objects that were returned from
-- the database once the object has finished loading.
-- ```
-- Object:all():get(function(results) ... end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:get(callback)
  self._expect = nil
  self._get = function(results)
    local all_objects = {}

    for k, v in ipairs(results) do
      table.insert(all_objects, v.object)
    end

    callback(all_objects)
  end

  return self
end

--- Runs the query.
-- Use this function to actually launch your queries.
-- ```
-- Object:all():get(function(results) ... end):fetch()
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:fetch()
  local callback = nil
  if self._expect then
    self:limit(1)
    callback = self._expect
    self._expect = nil
  elseif self._get then
    callback = self._get
    self._get = nil
  end
  return self:run_query(callback)
end

--- Used to catch errors during queries.
-- This callback is called in case no object was found in the database.
-- The callback's first argument is a new object of the same class pre-made for you.
-- ```
-- Object:where('id > 100000'):first():expect(obj)
--   ...
-- end):rescue(function(new_object)
--   ...
-- end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:rescue(callback)
  self._rescue = callback
  return self:fetch()
end

--- @ignore
local except = {
  id = true, created_at = true, updated_at = true
}

--- @ignore
local function gen_callback(self, insert)
  return function(result, query, time)
    print_query(self.class_name..' '..(insert and 'Create' or 'Update')..' ('..time..'s)', query)
    self.saving = false

    -- Set #id to last insert id.
    if insert and istable(result) then
      local r = result[1]
      self.id = r['id'] or r['last_insert_rowid()'] or r['last_insert_id()']
    end

    if insert and self.after_create then
      self:after_create()
    end

    if self.after_save then
      self:after_save()
    end

    -- save relations once we're done saving the thing
    if self.id and #self.relations > 0 then
      ar_add_indent()
      for _, relation in ipairs(self.relations) do
        if !relation.child then
          if relation.many and istable(self[relation.as]) then
            for k, v in ipairs(self[relation.as]) do
              v[relation.column_name] = self.id
              v:save()
            end
          elseif !relation.many and istable(self[relation.as]) then
            local rel = self[relation.as]
            if IsValid(rel) and isfunction(rel.save) then
              rel[relation.column_name] = self.id
              rel:save()
            end
          end
        end
      end
      ar_sub_indent()
    end
  end
end

--- Saves the object to the database.
-- This is the function that actually commits data to the database.
-- ```
-- local obj = Object.new()
--   obj.money = 100
-- obj:save()
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:save()
  if self.before_save then
    self:before_save(self.fetched)
  end

  ActiveRecord.Validator:validate_model(self, function()
    local schema = self:get_schema()

    self.saving = true

    if !self.fetched then
      self.fetched = true

      if self.before_create then
        self:before_create()
      end

      local query = ActiveRecord.Database:insert(self.table_name)
        for k, data in pairs(schema) do
          if except[k] then continue end
          query:insert(k, ActiveRecord.type_to_db(self[k], data.type))
        end
        query:insert('created_at', to_datetime(os.time()))
        query:insert('updated_at', to_datetime(os.time()))
        query:callback(gen_callback(self, true))
      query:execute()
    elseif self.id then
      local query = ActiveRecord.Database:update(self.table_name)
        query:where('id', self.id)
        for k, data in pairs(schema) do
          if except[k] then continue end
          query:update(k, ActiveRecord.type_to_db(self[k], data.type))
        end
        query:update('updated_at', to_datetime(os.time()))
        query:callback(gen_callback(self, false))
      query:execute()
    elseif !self.saving then
      ErrorNoHalt(self.class_name.." does not have a valid ID after saving. This should never happen!\n")
      ErrorNoHalt("Please report this issue to TeslaCloud along with your logs.\n")
    end
  end, function(model, column, err_code)
    if model.invalid then
      model:invalid(column, err_code)
    end
  end)

  return self
end

--- Deleted the current object from the database.
-- @warning [Once done, do not attempt saving the object again, since it will cause unpredictable behavior]
-- ```
-- obj:destroy()
-- -- do not use the object after this point.
-- ```
function ActiveRecord.Base:destroy()
  local class_name = self.class_name
  local query = ActiveRecord.Database:delete(self.table_name)
    query:where('id', self.id)
    query:callback(function(result, query, time)
      print_query(class_name..' Delete ('..time..'s)', query)
    end)
  query:execute()
  self = nil
end

--- @category [Database Relations]
-- Provides functions to bind multiple database-tied objects together.

--- Specifies that the object has one or many of another object.
-- The object(s) will be stored in a field with the same name
-- as child's database table.
-- ```
-- MyClass:has('User', true)
-- ...
-- MyClass:first():expect(function(obj)
--   print(obj.users) -- table
-- end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:has(what, many)
  local relation = {}
    local table_name = ''
    local should_add = true
    relation.child = false
    if istable(what) then
      table_name = what[1]:underscore()
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
    relation.column_name = self.class_name:underscore()..'_id'
    if should_add then
      local index = table.insert(self.relations, relation)
      self.relations[table_name] = index
    end
  return self
end

--- Specifies that the object has many instances of another object.
-- The objects will be stored in a field with the same name
-- as child's database table.
-- ```
-- MyClass:has_many 'users'
-- ...
-- MyClass:first():expect(function(obj)
--   print(obj.users) -- table
-- end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:has_many(what)
  return self:has(what, true)
end

--- Specifies that the object has one instance of another object.
-- The object will be stored in a field with the same name
-- as child's database table.
-- ```
-- MyClass:has_one 'user'
-- ...
-- MyClass:first():expect(function(obj)
--   print(obj.user) -- #<User>
-- end)
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:has_one(what)
  return self:has({ Flow.Inflector:pluralize(what), as = what }, false)
end

--- Specifies that the object belongs to a parent object.
-- ```
-- MyClass:belongs_to 'user'
-- ```
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:belongs_to(target, one)
  if isstring(target) then
    target = target:parse_table()
  end
  if istable(target) then
    target:has(self.table_name, !one)
    table.insert(self.relations, {
      child = true,
      as = target.class_name:underscore(),
      target_class = target
    })
  end
  return self
end

--- Callback that is called if object's validation fails.
function ActiveRecord.Base:invalid(column, err_code)
  ErrorNoHalt('ActiveRecord - Validation failed!\n')
  ErrorNoHalt(self.class_name..'#'..tostring(column)..' failed with error code '..tostring(err_code)..'\n')
end

--- Specifies a validation for a column.
-- ```
-- MyObject:validates('email', { presence = true, uniqueness = true })
-- ```
-- See all available validations in ActiveRecord::Validator.
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:validates(column, options)
  local current_options = self.validations[column] or {}
  for k, v in pairs(options) do
    if id == 'case_sensitive' then -- todo: unhack this
      current_options.case_sensitive = v
    else
      table.insert(current_options, { id = k, value = v })
    end
  end
  self.validations[column] = current_options
  return self
end
