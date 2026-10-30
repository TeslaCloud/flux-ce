--- The model class of ActiveRecord. A model is a class that extends `ActiveRecord::Base`;
-- it is tied to the database table named after the lowercase plural of its class name,
-- and each of its objects stands for one row, with the columns of the table as fields.
--
-- Objects are loaded by chaining query methods (`where`, `order`, `limit`, `preload` and so
-- on) on the class, naming a callback with `expect` (a single object, nil when nothing is
-- found) or `get` (a list, empty when nothing is found) and then launching the query with
-- `fetch`, or with `rescue`, which also names the callback for when nothing is found and
-- hands it a new object instead. Every chain builds a query of its own: the first query
-- method called on a class or an object starts a new query object, which inherits
-- everything else from the class or object, and the methods after it add to that query
-- object. Queries built at the same time, or one that is never launched, do not affect each
-- other. `update_all` and `delete_all` change or delete every row the conditions of a chain
-- match with one query, without loading any object.
--
-- Models are related to each other with `has_many`, `has_one` and `belongs_to`. A query
-- loads the rows of its own table only: the relations of the loaded objects are loaded when
-- the query names them with `preload`, nested relations included, and `load_relations`
-- loads them for objects that are loaded already. Reading a relation that was not loaded
-- gives nil, whereas a loaded `has_many` without rows is an empty list; a new object starts
-- with empty `has_many` lists.
--
-- `save` validates an object, inserts or updates its row and saves the objects of its loaded
-- `has_many` and `has_one` relations; relations that were not loaded are left alone. `destroy`
-- deletes the row of the object alone. Models are validated with `validates`, and may define
-- the `before_save`, `before_create`, `after_create`, `after_save` and `restored` callbacks.
--
-- The file is also sent to the client, where the methods that need the database are
-- replaced by stubs.

local concat = table.concat
local istable = istable
local isfunction = isfunction

--- Base class for ActiveRecord database-tied objects.
-- These objects are also referred to as "models".
class 'ActiveRecord::Base'

--- Database table the object is tied to.
-- @return [String]
ActiveRecord.Base.table_name  = ''

--- Database schema of the object.
-- This table contains all the columns that are written to the database.
-- @return [Map]
ActiveRecord.Base.schema      = nil

--- @warning [Internal]
-- Class relations of the object.
-- Serves as a list of objects that are children to this object
-- or that this object is a child to.
-- @return [Map]
ActiveRecord.Base.relations   = {}

--- @warning [Internal]
-- List of validations to be run when the object is being saved,
-- as well as some internal data related to them.
-- @return [Map]
ActiveRecord.Base.validations = {}

--- @warning [Internal]
-- Sets up basic variables and creates empty lists for the relations that the object has
-- many of, since a new object has no children yet.
function ActiveRecord.Base:init()
  self.fetched = false
  self.saving = false

  for _, relation in ipairs(self.relations) do
    if relation.many and !self[relation.as] then
      self[relation.as] = {}
    end
  end
end

--- @warning [Internal]
-- When the ActiveRecord::Base class is extended,
-- the new model is added to the global models list,
-- and its table name is determined based on the class name.
-- Make sure you create a table that is named as a lowercase plural
-- of the class name, or else this will fail!
-- @param new_class [ActiveRecord::Base the newly created model class]
function ActiveRecord.Base:class_extended(new_class)
  new_class.table_name = ActiveRecord.Inflector:pluralize(new_class.class_name:underscore())

  ActiveRecord.Model:add(new_class)
end

--- Returns the database schema, or attempts to get it from the global schema
-- storage in case the object hasn't been properly initialized yet.
-- @return [Map schema]
function ActiveRecord.Base:get_schema()
  self.schema = self.schema or ActiveRecord.schema[self.table_name] or {}
  return self.schema
end

--- Dump the object as a simple data table.
-- This simply dumps all the values of the variables defined in the schema.
-- @return [Map schema, ActiveRecord::Base(self)]
function ActiveRecord.Base:dump()
  local ret = {}

  for column in pairs(self:get_schema()) do
    ret[column] = self[column]
  end

  return ret, self
end

--- @category [Query Engine]
-- Provides utility functions for abstracted database querying.

--- @ignore
-- Returns the query object that a query method works on. A model class or object starts a
-- new query object, which holds the state of the query (the conditions in its query_map and
-- the callbacks) and inherits everything else from the class or object through __index. A
-- query object is returned as it is, so that every method of a chain adds to the same query.
local function query_of(self)
  if rawget(self, 'is_query') then
    return self
  end

  return setmetatable({ is_query = true, query_map = a{} }, { __index = self })
end

local function bind_list(values, list)
  local placeholders = {}

  for index, value in ipairs(list) do
    values[#values + 1] = value
    placeholders[index] = '?'
  end

  return concat(placeholders, ', ')
end

--- @ignore
-- Adds the relation names of a preload specification to a preload tree, which maps every
-- relation name to the tree of its own nested relations. A specification is a relation name,
-- or a table whose list part holds specifications and whose hash part maps relation names to
-- the specification of their nested relations.
local function merge_preloads(tree, spec)
  if isstring(spec) then
    tree[spec] = tree[spec] or {}
  elseif istable(spec) then
    for key, value in pairs(spec) do
      if isnumber(key) then
        merge_preloads(tree, value)
      elseif isstring(key) then
        local nested = tree[key] or {}

        tree[key] = nested

        merge_preloads(nested, value)
      end
    end
  end

  return tree
end

local function find_relation(relations, name)
  for _, relation in ipairs(relations) do
    if relation.as == name then
      return relation
    end
  end
end

--- @ignore
-- Raises an error at the caller of a query method when the preload tree names a relation
-- that the model does not have or that has no model to load.
local function check_preloads(model, tree)
  for name in pairs(tree) do
    local relation = find_relation(model.relations, name)

    if !relation then
      error(model.class_name..' has no relation named \''..tostring(name)..'\'', 3)
    elseif !(relation.child and relation.target_class or relation.model) then
      error('relation \''..name..'\' of '..model.class_name..' has no model', 3)
    end
  end
end

--- Specifies a WHERE condition in the query.
-- The values are passed to the database as bind parameters, so they need no escaping.
-- ```
-- Object:where('column', 'value')
-- Object:where('column > ?', 100)
-- Object:where({ ['column'] = 'value', ['column2'] = { 'value', 'value2' } })
-- ```
-- @param condition [String/Map column name, SQL condition (which may use ? placeholders),
--   or a hash of column-value pairs in which a List value stands for IN (...)]
-- @param ... [Vararg value to compare the column with (nil stands for IS NULL), or the
--   values that replace the ? placeholders]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:where(condition, ...)
  local arg_count = select('#', ...)
  local args = { ... }
  local query_str = ''
  local values = nil

  if arg_count > 0 then
    if condition:find('[=<>?]') then
      values = args
      query_str = condition
    elseif arg_count == 1 and args[1] == nil then
      query_str = condition..' IS NULL'
    else
      values = args
      query_str = condition..' = ?'
    end
  elseif istable(condition) then
    local parts = {}

    values = {}

    for column, value in pairs(condition) do
      if !istable(value) then
        parts[#parts + 1] = column..' = ?'
        values[#values + 1] = value
      else
        parts[#parts + 1] = column..' IN ('..bind_list(values, value)..')'
      end
    end

    query_str = concat(parts, ' AND ')
  elseif isstring(condition) then
    query_str = condition
  end

  local query = query_of(self)

  query.query_map:insert { 'where', query_str, values }

  return query
end

--- Specifies a WHERE NOT condition in the query.
-- Works exactly the same as #where, except that it does the opposite.
-- ```
-- Object:where_not('column', 'value')
-- Object:where_not('column > ?', 100)
-- Object:where_not({ ['column'] = 'value', ['column2'] = { 'value', 'value2' } })
-- ```
-- @param condition [String/Map column name, SQL condition (which may use ? placeholders),
--   or a hash of column-value pairs in which a List value stands for NOT IN (...)]
-- @param ... [Vararg value to compare the column with (nil stands for IS NOT NULL), or
--   the values that replace the ? placeholders]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:where_not(condition, ...)
  local arg_count = select('#', ...)
  local args = { ... }
  local query_str = ''
  local values = nil

  if arg_count > 0 then
    if condition:find('[=<>?]') then
      values = args
      query_str = 'NOT ('..condition..')'
    elseif arg_count == 1 and args[1] == nil then
      query_str = condition..' IS NOT NULL'
    else
      values = args
      query_str = 'NOT ('..condition..' = ?)'
    end
  elseif istable(condition) then
    local parts = {}

    values = {}

    for column, value in pairs(condition) do
      if !istable(value) then
        parts[#parts + 1] = column..' != ?'
        values[#values + 1] = value
      else
        parts[#parts + 1] = column..' NOT IN ('..bind_list(values, value)..')'
      end
    end

    query_str = concat(parts, ' AND ')
  elseif isstring(condition) then
    query_str = 'NOT ('..condition..')'
  end

  local query = query_of(self)

  query.query_map:insert { 'where', query_str, values }

  return query
end

--- Returns the first object stored in the database.
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:first()
  return self:order('id'):limit(1)
end

--- Returns the last object stored in the database.
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:last()
  return self:order('id', 'desc'):limit(1)
end

--- Returns all of the objects stored in the database.
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:all()
  return self:order('id')
end

--- Inserts an ORDER BY condition into the query.
-- ```
-- Object:order('id', 'asc')
-- ```
-- @param column [String column to sort by]
-- @param direction=nil [String lowercase 'asc' or 'desc'; sorts in ascending order
--   if omitted]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:order(column, direction)
  local query = query_of(self)

  query.query_map:insert { 'order', column, direction }

  return query
end

--- Finds an object in the database by its ID.
-- Optionally can also call a callback right away.
-- ```
-- Object:find(1)
-- Object:find(1, function(obj) ... end)
-- ```
-- @param id [Number]
-- @param callback=nil [Function passed to #expect, receives the object that was found]
-- @return [ActiveRecord::Base query object]
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
-- @param column [String]
-- @param value [Any value to look for, converted to a string]
-- @param callback=nil [Function passed to #expect, receives the object that was found]
-- @return [ActiveRecord::Base query object]
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
-- @param amt [Number maximum amount of objects to load]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:limit(amt)
  local query = query_of(self)

  query.query_map:insert { 'limit', amt }

  return query
end

--- Inserts an OFFSET condition into the query.
-- The code in the example below will return the SECOND entry in the database:
-- ```
-- Object:where('money > 100'):skip(1):limit(1)
-- ```
-- @param amt [Number amount of objects to skip]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:skip(amt)
  local query = query_of(self)

  query.query_map:insert { 'offset', amt }

  return query
end

--- Names the relations that are loaded together with the objects of the query. Without it a
-- query loads none: reading a relation that was not loaded gives nil, on the objects and on
-- their children alike. Each relation is loaded with one query for up to 500 objects at a
-- time; nested relations are named in a table under the name of their parent relation.
-- Calling it again adds to the relations named before.
-- ```
-- User:where('steam_id', steam_id):preload('characters', 'whitelists'):expect(function(user)
--   print(#user.characters)
-- end):fetch()
--
-- User:all():preload({ characters = { 'skills', attributes = { 'attribute_boosts' } } }):get(function(users)
--   ...
-- end):fetch()
-- ```
-- @param ... [Vararg relation names, as the fields they are stored in, or tables that list
--   them and map a relation name to the relations to load for its objects]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:preload(...)
  local tree = merge_preloads({}, { ... })

  check_preloads(self, tree)

  local query = query_of(self)

  query.query_map:insert { 'preload', tree }

  return query
end

--- @warning [Internal]
-- Internal function to process child objects or the current object as a child to another object.
-- @param obj [ActiveRecord::Base parent object]
-- @param target_class [ActiveRecord::Base class of the parent object]
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
    for _, relation in ipairs(self.relations) do
      if relation.child and relation.target_class == target_class then
        self[relation.as] = obj
        break
      end
    end
  end

  return self
end

local relation_batch_size = 500

--- @ignore
-- Loads one relation of a list of objects, with one query for up to 500 of them at a time,
-- and the nested relations of the loaded objects with it. A `has_many` field of each object
-- becomes a list, empty when there are no rows; a `has_one` or `belongs_to` field without a
-- row becomes nil.
-- @param relation [Map]
-- @param objects [List<ActiveRecord::Base>]
-- @param nested [Map preload tree of the loaded objects, nil to load no nested relations]
-- @param callback [Function called once the relation of every object has been loaded]
-- @param offset=0 [Number amount of objects whose relation has been loaded already]
local function fetch_relation(relation, objects, nested, callback, offset)
  offset = offset or 0

  local child = relation.child
  local field = relation.as
  local key_column = child ? 'id' : relation.column_name
  local last = math.min(offset + relation_batch_size, #objects)
  local owners_by_key = {}
  local keys = {}

  for i = offset + 1, last do
    local object = objects[i]
    local key = nil

    if child then
      key = object[relation.column_name]
    else
      key = object.id
    end

    object[field] = relation.many ? {} : nil

    if key != nil then
      local id = tostring(key)
      local owners = owners_by_key[id]

      if !owners then
        owners = {}
        owners_by_key[id] = owners
        keys[#keys + 1] = key
      end

      owners[#owners + 1] = object
    end
  end

  local function proceed()
    if last < #objects then
      return fetch_relation(relation, objects, nested, callback, last)
    end

    callback()
  end

  if #keys == 0 then
    return proceed()
  end

  local query = (child and relation.target_class or relation.model):where({ [key_column] = keys }):order('id')

  if nested then
    query:preload(nested)
  end

  query:get(function(rows)
    for _, row in ipairs(rows) do
      local owners = owners_by_key[tostring(row[key_column])]

      if !owners then continue end

      for _, owner in ipairs(owners) do
        if child then
          owner[field] = row
        elseif relation.many then
          local list = owner[field]

          list[#list + 1] = row
          row:_process_child(owner, owner.class)
        elseif owner[field] == nil then
          owner[field] = row
          row:_process_child(owner, owner.class)
        end
      end
    end

    proceed()
  end):fetch()
end

--- @warning [Internal]
-- Loads the relations named in a preload tree for a list of objects of the model, one
-- relation after another, and then calls the callback with the objects.
-- @param objects [List<ActiveRecord::Base> objects to load the relations of]
-- @param preloads [Map preload tree: relation names mapped to the trees of their nested
--   relations]
-- @param callback [Function called with the objects once their relations have been loaded]
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:_fetch_relations(objects, preloads, callback)
  local names = table.GetKeys(preloads)
  local index = 0

  table.sort(names)

  local function load_next()
    index += 1

    local name = names[index]

    if !name then
      return callback(objects)
    end

    local nested = preloads[name]

    fetch_relation(find_relation(self.relations, name), objects, next(nested) != nil and nested or nil, load_next)
  end

  load_next()

  return self
end

--- Loads relations of objects that are loaded already, with the same batched queries as
-- #preload, and replaces whatever their relation fields held. Called on an object it loads
-- the relations of that object; called on a list of objects of one model, as
-- `ActiveRecord.Base.load_relations(objects, ...)`, those of every object in it.
-- ```
-- character:load_relations('recognizes', function(character)
--   print(#character.recognizes)
-- end)
--
-- ActiveRecord.Base.load_relations(characters, { attributes = { 'attribute_boosts' } }, function(characters)
--   ...
-- end)
-- ```
-- @param preloads [String/Map relation name, or a table of them as #preload takes it]
-- @param callback=nil [Function called with the object or the list once the relations have
--   been loaded]
-- @return [ActiveRecord::Base/List the object or the list]
function ActiveRecord.Base:load_relations(preloads, callback)
  local objects = self.static_class == false ? { self } : self
  local model = objects[1]?.class

  if !model then
    if callback then
      callback(self)
    end

    return self
  end

  local tree = merge_preloads({}, preloads)

  check_preloads(model, tree)

  model:_fetch_relations(objects, tree, function()
    if callback then
      callback(self)
    end
  end)

  return self
end

--- @warning [Internal]
-- Runs the query based on the query map of the query object and flushes the query map.
-- The callback, the #rescue callback and the conditions are taken from the query object
-- when the query is sent. When nothing is found, the #rescue callback is called with a new
-- object if there is one, and the callback with an empty list otherwise. The relations
-- named with #preload are loaded before the callback is called.
-- @param callback [Function called with a List of the loaded objects]
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:run_query(callback)
  local query_map = self.query_map

  if istable(query_map) and #query_map > 0 then
    local query = ActiveRecord.Database:select(self.table_name)
    local rescue = self._rescue
    local preloads = nil

    for _, entry in ipairs(query_map) do
      local t, a, b = entry[1], entry[2], entry[3]

      if t == 'where' then
        query:where_raw(a, b)
      elseif t == 'order' then
        if b then
          query:order({ [b] = a })
        else
          query:order(a)
        end
      elseif t == 'limit' then
        query:limit(a)
      elseif t == 'offset' then
        query:offset(a)
      elseif t == 'preload' then
        preloads = merge_preloads(preloads or {}, a)
      end
    end

    self.query_map = a{}
    self._rescue = nil

    query:callback(function(results, query_str, time, bindings)
      print_query(self.class_name..' Load ('..time..'s)', query_str, bindings)

      local found = istable(results) and #results > 0

      if !found and isfunction(rescue) then
        rescue(self.class.new())

        if isfunction(self.created) then
          self:created()
        end

        return
      end

      if !isfunction(callback) then return end

      local objects = {}

      if found then
        for i = 1, #results do
          objects[i] = self:_create_restored(results[i])
        end
      end

      if !preloads or next(preloads) == nil or #objects == 0 then
        return callback(objects)
      end

      ar_add_indent()
      self:_fetch_relations(objects, preloads, callback)
      ar_sub_indent()
    end)

    query:execute()
  end

  return self
end

--- @warning [Internal]
-- Internal function to create a new instance of the object based on the
-- data from the database. The relations of the instance are not loaded, so its `has_many`
-- fields are nil.
-- @param data [Map row returned by the database]
-- @return [ActiveRecord::Base(object)]
function ActiveRecord.Base:_create_restored(data)
  local object = self.class.new()
  object.id = data.id
  object.fetched = true

  for _, relation in ipairs(self.relations) do
    if relation.many then
      object[relation.as] = nil
    end
  end

  local schema = ActiveRecord.schema[self.table_name] or {}
  local str_to_type = ActiveRecord.str_to_type

  for column_name, value in pairs(data) do
    local column = schema[column_name]

    object[column_name] = str_to_type(value, column and column.type or 'string')
  end

  if isfunction(object.restored) then
    object:restored()
  end

  return object
end

--- Used when a single return value is expected.
-- Calls the callback with a single object when the object has
-- finished loading from the database, or with nil when nothing was found.
-- ```
-- Object:first():expect(function(obj) ... end):fetch()
-- ```
-- @param callback [Function receives the loaded object, nil when nothing was found]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:expect(callback)
  local query = query_of(self)

  query._get = nil
  query._expect = |results| -> callback(results[1])

  return query
end

--- Used when multiple return values are expected.
-- Calls the callback with all objects that were returned from
-- the database once the object has finished loading.
-- ```
-- Object:all():get(function(results) ... end):fetch()
-- ```
-- @param callback [Function receives a List of the loaded objects, empty when nothing was
--   found]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:get(callback)
  local query = query_of(self)

  query._expect = nil
  query._get = callback

  return query
end

--- Runs the query.
-- Use this function to actually launch your queries.
-- ```
-- Object:all():get(function(results) ... end):fetch()
-- ```
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:fetch()
  local query = query_of(self)
  local callback = nil

  if query._expect then
    query:limit(1)
    callback = query._expect
    query._expect = nil
  elseif query._get then
    callback = query._get
    query._get = nil
  end

  return query:run_query(callback)
end

--- Runs the query like #fetch, with a callback for when nothing is found in the database
-- instead of the #expect or #get callback. The callback's first argument is a new object of
-- the same class pre-made for you.
-- ```
-- Object:where('id > 100000'):first():expect(function(obj)
--   ...
-- end):rescue(function(new_object)
--   ...
-- end)
-- ```
-- @param callback [Function receives a new, unsaved object of the same class]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:rescue(callback)
  local query = query_of(self)

  query._rescue = callback

  return query:fetch()
end

--- @ignore
-- Collects the WHERE conditions of a query map into a query of the Database layer for
-- #update_all and #delete_all, and raises an error at their caller for a LIMIT or OFFSET,
-- which those statements do not take on every database.
local function apply_conditions(query, query_map, method)
  for _, entry in ipairs(query_map) do
    local kind = entry[1]

    if kind == 'where' then
      query:where_raw(entry[2], entry[3])
    elseif kind == 'limit' or kind == 'offset' then
      error(method..' does not take a '..kind, 3)
    end
  end
end

--- Changes columns of every row that the conditions of the query match, with a single
-- UPDATE and without loading any object, and sets their `updated_at` as #save does. Objects
-- that are loaded already keep their values. Without conditions every row is changed.
-- ```
-- User:where('steam_id', steam_id):update_all({ role = 'admin' }, function() ... end)
-- ```
-- @param fields [Map new values keyed by column name]
-- @param callback=nil [Function called without arguments once the rows have been changed]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:update_all(fields, callback)
  local query = query_of(self)
  local schema = self:get_schema()
  local type_to_db = ActiveRecord.type_to_db
  local statement = ActiveRecord.Database:update(self.table_name)

  apply_conditions(statement, query.query_map, 'update_all')

  for column, value in pairs(fields) do
    local column_data = schema[column]

    if column_data then
      value = type_to_db(value, column_data.type)
    end

    statement:update(column, value)
  end

  if fields.updated_at == nil then
    statement:update('updated_at', to_datetime(os.time()))
  end

  query.query_map = a{}

  statement:callback(function(_result, query_str, time, bindings)
    print_query(self.class_name..' Update All ('..time..'s)', query_str, bindings)

    if isfunction(callback) then
      callback()
    end
  end)

  statement:execute()

  return query
end

--- Deletes every row that the conditions of the query match, with a single DELETE and
-- without loading any object or running their callbacks. Without conditions every row is
-- deleted.
-- ```
-- CharacterPermission:where('character_id', id):delete_all()
-- ```
-- @param callback=nil [Function called without arguments once the rows have been deleted]
-- @return [ActiveRecord::Base query object]
function ActiveRecord.Base:delete_all(callback)
  local query = query_of(self)
  local statement = ActiveRecord.Database:delete(self.table_name)

  apply_conditions(statement, query.query_map, 'delete_all')

  query.query_map = a{}

  statement:callback(function(_result, query_str, time, bindings)
    print_query(self.class_name..' Delete All ('..time..'s)', query_str, bindings)

    if isfunction(callback) then
      callback()
    end
  end)

  statement:execute()

  return query
end

--- @ignore
local except = {
  id = true, created_at = true, updated_at = true
}

local function gen_callback(self, insert)
  return function(result, query, time, bindings)
    print_query(self.class_name..' '..(insert ? 'Create' : 'Update')..' ('..time..'s)', query, bindings)
    self.saving = false

    if insert and istable(result) and istable(result[1]) then
      self.id = result[1]['id']
    end

    if insert and self.after_create then
      self:after_create()
    end

    if self.after_save then
      self:after_save()
    end

    if self.id and #self.relations > 0 then
      ar_add_indent()

      for _, relation in ipairs(self.relations) do
        if !relation.child then
          if relation.many and istable(self[relation.as]) then
            for _, child in ipairs(self[relation.as]) do
              child[relation.column_name] = self.id
              child:save()
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

    if self._save_pending then
      self._save_pending = nil
      self:save()
    end
  end
end

--- Saves the object to the database.
-- This is the function that actually commits data to the database. Once the row is
-- written, the objects of the loaded `has_many` and `has_one` relations are saved as well;
-- a relation that was not loaded is nil and left alone, so its rows stay as they are.
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
    local in_flight = self.saving

    self.saving = true

    if !self.fetched then
      self.fetched = true

      if self.before_create then
        self:before_create()
      end

      local type_to_db = ActiveRecord.type_to_db
      local now = to_datetime(os.time())
      local query = ActiveRecord.Database:insert(self.table_name)
        for column, data in pairs(schema) do
          if except[column] then continue end

          query:insert(column, type_to_db(self[column], data.type))
        end

        query:insert('created_at', now)
        query:insert('updated_at', now)
        query:callback(gen_callback(self, true))
        query:on_error(function()
          self.fetched = false
          self.saving = false
          self._save_pending = nil
        end)
      query:execute()
    elseif self.id then
      local type_to_db = ActiveRecord.type_to_db
      local query = ActiveRecord.Database:update(self.table_name)
        query:where('id', self.id)

        for column, data in pairs(schema) do
          if except[column] then continue end

          query:update(column, type_to_db(self[column], data.type))
        end

        query:update('updated_at', to_datetime(os.time()))
        query:callback(gen_callback(self, false))
        query:on_error(function()
          self.saving = false
        end)
      query:execute()
    elseif in_flight then
      self._save_pending = true
    else
      self.saving = false

      ErrorNoHalt(self.class_name..' does not have a valid ID after saving. This should never happen!\n')
      ErrorNoHalt('Please report this issue to TeslaCloud along with your logs.\n')
    end
  end, function(model, column, err_code)
    if model.invalid then
      model:invalid(column, err_code)
    end
  end)

  return self
end

--- Deletes the current object from the database. The rows of its relations are left to
-- the foreign keys of the database.
-- @warning [Once done, do not attempt saving the object again, since it will cause unpredictable behavior]
-- ```
-- obj:destroy()
-- -- do not use the object after this point.
-- ```
function ActiveRecord.Base:destroy()
  local class_name = self.class_name
  local query = ActiveRecord.Database:delete(self.table_name)
    query:where('id', self.id)
    query:callback(function(_result, query_str, time, bindings)
      print_query(class_name..' Delete ('..time..'s)', query_str, bindings)
    end)
  query:execute()
end

--- @category [Database Relations]
-- Provides functions to bind multiple database-tied objects together.

--- Specifies that the object has one or many of another object.
-- The object(s) will be stored in a field with the same name
-- as the child's database table, once the relation is loaded with #preload or
-- #load_relations; until then the field is nil.
-- ```
-- MyClass:has('users', true)
-- ...
-- MyClass:first():preload('users'):expect(function(obj)
--   print(obj.users) -- table
-- end):fetch()
-- ```
-- @param what [String/Map table name of the child model, or a hash such as
--   { 'table_name', as = 'field_name' } to store the object(s) in another field]
-- @param many [Boolean true if the object has many of them, false if it has only one]
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:has(what, many)
  local relation = { child = false }
  local table_name = ''
  local should_add = true

  if istable(what) then
    table_name = what[1]:underscore()
    relation.as = what.as or table_name
  elseif isstring(what) then
    table_name = what
    relation.as = table_name
  end

  if self.relations[table_name] then
    relation = self.relations[self.relations[table_name]]

    if !many then
      relation.many = false
    end

    should_add = false
  else
    relation.many = many
  end

  for _, model in pairs(ActiveRecord.Model:all()) do
    if model.table_name == table_name then
      relation.model = model
      break
    end
  end

  relation.table_name = table_name
  relation.column_name = self.class_name:underscore()..'_id'

  if should_add then
    local index = #self.relations + 1

    self.relations[index] = relation
    self.relations[table_name] = index
  end

  return self
end

--- Specifies that the object has many instances of another object.
-- The objects will be stored in a field with the same name
-- as the child's database table, once the relation is loaded with #preload or
-- #load_relations; until then the field is nil, and it is an empty list for a new object.
-- ```
-- MyClass:has_many 'users'
-- ...
-- MyClass:first():preload('users'):expect(function(obj)
--   print(obj.users) -- table
-- end):fetch()
-- ```
-- @param what [String/Map table name of the child model, or a hash such as
--   { 'table_name', as = 'field_name' } to store the objects in another field]
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:has_many(what)
  return self:has(what, true)
end

--- Specifies that the object has one instance of another object.
-- The object will be stored in a field named after the child model, once the relation is
-- loaded with #preload or #load_relations; until then, and when there is no such object,
-- the field is nil.
-- ```
-- MyClass:has_one 'user'
-- ...
-- MyClass:first():preload('user'):expect(function(obj)
--   print(obj.user) -- #<User>
-- end):fetch()
-- ```
-- @param what [String singular underscored name of the child model, e.g. 'ammunition']
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:has_one(what)
  return self:has({ ActiveRecord.Inflector:pluralize(what), as = what }, false)
end

--- Specifies that the object belongs to a parent object. The parent is stored in a field
-- named after the parent model (`user` for 'User'), found by the `<field>_id` column. It is
-- set when the parent loads this object as its child, or when the relation is loaded with
-- #preload or #load_relations; until then the field is nil.
-- ```
-- MyClass:belongs_to 'User'
-- ...
-- MyClass:first():preload('user'):expect(function(obj)
--   print(obj.user) -- #<User>
-- end):fetch()
-- ```
-- @param target [String/ActiveRecord::Base class of the parent model, or its name
--   (e.g. 'User')]
-- @param one=false [Boolean true if the parent has only one of this object, rather
--   than many]
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:belongs_to(target, one)
  if isstring(target) then
    target = target:parse_table()
  end

  if istable(target) then
    local field = target.class_name:underscore()

    target:has(self.table_name, !one)
    table.insert(self.relations, {
      child = true,
      as = field,
      column_name = field..'_id',
      target_class = target
    })
  end

  return self
end

--- Callback that is called if the object's validation fails.
-- @param column [String column that failed the validation]
-- @param err_code [String id of the failed validation, e.g. 'presence']
function ActiveRecord.Base:invalid(column, err_code)
  ErrorNoHalt('ActiveRecord - Validation failed!\n')
  ErrorNoHalt(self.class_name..'#'..tostring(column)..' failed with error code '..tostring(err_code)..'\n')
end

--- Specifies a validation for a column.
-- ```
-- MyObject:validates('email', { presence = true, uniqueness = true })
-- ```
-- See all available validations in ActiveRecord::Validator.
-- @param column [String]
-- @param options [Map validation ids mapped to their settings, e.g. { min_length = 4 };
--   case_sensitive = true makes the uniqueness validation of the column compare case]
-- @return [ActiveRecord::Base(self)]
function ActiveRecord.Base:validates(column, options)
  local current_options = self.validations[column] or {}

  for option, value in pairs(options) do
    if option == 'case_sensitive' then
      current_options.case_sensitive = value
    else
      current_options[#current_options + 1] = { id = option, value = value }
    end
  end

  self.validations[column] = current_options
  return self
end
