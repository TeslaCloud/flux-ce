--- A single SQL query under construction. A query is created through
-- `ActiveRecord::Database` for one table and one type; its methods collect conditions,
-- values, ordering and column definitions, and `execute` builds the SQL in the dialect of
-- the current adapter and hands it over to be run. The methods return nothing, so calls
-- are not chained. Values given to `where`, `insert` and `update` are sent to the
-- database as bind parameters, apart from the SQL, and need no escaping.
--
-- 'create' and 'change' queries also get a method for every column type of the adapter
-- (`query:string`, `query:integer` and so on) along with `timestamps` and `references`:
-- they are the `t` that `create_table` and `change_table` hand to their callback.

--[[
  mysql - 2.0.0
  A simple Database wrapper for Garry's Mod.

  Alexander Grist-Hucker
  http://www.alexgrist.com

  Meow the Cat
  https://teslacloud.net
--]]

local concat = table.concat
local gsub = string.gsub
local tostring = tostring
local isstring = isstring
local istable = istable
local isnumber = isnumber

class 'ActiveRecord::Query'

local queries_with_create = {
  create = true, change = true
}

local queries_with_bindings = {
  select = true, insert = true, update = true, delete = true
}

--- Creates an empty query. Queries are normally created through ActiveRecord::Database.
-- @param table_name [String]
-- @param query_type [String 'select', 'insert', 'update', 'delete', 'drop', 'truncate',
--   'create' or 'change']
function ActiveRecord.Query:init(table_name, query_type)
  self.query_type = query_type
  self.table_name = table_name
  self.select_list = {}
  self.insert_list = {}
  self.update_list = {}
  self.create_list = {}
  self.where_list = {}
  self.order_list = {}
  self.remove_column_list = {}
  self.rename_list = {}
  self.bindings = {}

  if queries_with_create[query_type:lower()] then
    ActiveRecord.generate_create_funcs(self)
  end
end

--- Appends the NOT NULL / DEFAULT clauses to the definition of the column that is
-- being created.
-- @param args [Map column options: null (Boolean) and default (inserted into the SQL as is)]
function ActiveRecord.Query:handle_create_args(args)
  if args['null'] == false then
    self.def = self.def..' NOT NULL'
  elseif args['null'] == true then
    self.def = self.def..' DEFAULT NULL'
  end

  if args['default'] != nil and args['null'] != true then
    self.def = self.def..' DEFAULT '..tostring(args['default'])
  end
end

--- Escapes a value for use inside an SQL string literal.
-- @param text [Any value to escape, converted to a string]
-- @return [String]
function ActiveRecord.Query:escape(text)
  return ActiveRecord.adapter:escape(tostring(text))
end

--- Turns a value into an escaped, quoted SQL string literal.
-- @param text [Any value to quote, converted to a string; nil becomes NULL]
-- @return [String]
function ActiveRecord.Query:quote(text)
  if text == nil then
    return 'NULL'
  else
    return ActiveRecord.adapter:quote(tostring(text))
  end
end

--- Quotes an identifier such as a table or column name.
-- @param text [Any identifier, converted to a string]
-- @return [String]
function ActiveRecord.Query:quote_column(text)
  return ActiveRecord.adapter:quote_name(tostring(text))
end

--- Adds a value to the bind parameters of the query. The value is sent to the database
-- apart from the SQL, so nothing in it has to be escaped.
-- @param value [Any value to bind, converted to a string]
-- @return [String placeholder that stands for the value in the SQL; NULL if the value
--   is nil]
function ActiveRecord.Query:bind(value)
  if value == nil then
    return 'NULL'
  end

  local bindings = self.bindings
  local index = #bindings + 1

  bindings[index] = tostring(value)

  return ActiveRecord.adapter:placeholder(index)
end

--- Changes the table the query operates on.
-- @param table_name [String]
function ActiveRecord.Query:for_table(table_name)
  self.table_name = table_name
end

--- Adds a "column = value" condition. Multiple conditions are joined with AND.
-- @param key [String column name]
-- @param value [Any value to compare with, converted to a string]
-- @see [ActiveRecord::Query#where_equal]
function ActiveRecord.Query:where(key, value)
  self:where_equal(key, value)
end

--- Adds a raw SQL condition. Nothing in it is escaped or quoted.
-- ```
-- query:where_raw('money > 100')
-- query:where_raw('money > ? AND name != ?', { 100, 'John' })
-- ```
-- @param condition [String SQL condition]
-- @param values=nil [List values that are bound in place of the ? placeholders in the
--   condition. Without it the question marks in the condition are left as they are]
function ActiveRecord.Query:where_raw(condition, values)
  local where_list = self.where_list

  where_list[#where_list + 1] = { condition, values }
end

--- Adds a "column = value" condition.
-- @param key [String column name]
-- @param value [Any value to compare with, converted to a string]
function ActiveRecord.Query:where_equal(key, value)
  self:where_raw(self:quote_column(key)..' = ?', { value })
end

--- Adds a "column != value" condition.
-- @param key [String column name]
-- @param value [Any value to compare with, converted to a string]
function ActiveRecord.Query:where_not_equal(key, value)
  self:where_raw(self:quote_column(key)..' != ?', { value })
end

--- Adds a "column LIKE pattern" condition.
-- @param key [String column name]
-- @param value [String SQL LIKE pattern]
function ActiveRecord.Query:where_like(key, value)
  self:where_raw(self:quote_column(key)..' LIKE ?', { value })
end

--- Adds a "column NOT LIKE pattern" condition.
-- @param key [String column name]
-- @param value [String SQL LIKE pattern]
function ActiveRecord.Query:where_not_like(key, value)
  self:where_raw(self:quote_column(key)..' NOT LIKE ?', { value })
end

--- Adds a "column > value" condition.
-- @param key [String column name]
-- @param value [Any value to compare with, converted to a string]
function ActiveRecord.Query:where_gt(key, value)
  self:where_raw(self:quote_column(key)..' > ?', { value })
end

--- Adds a "column < value" condition.
-- @param key [String column name]
-- @param value [Any value to compare with, converted to a string]
function ActiveRecord.Query:where_lt(key, value)
  self:where_raw(self:quote_column(key)..' < ?', { value })
end

--- Adds a "column >= value" condition.
-- @param key [String column name]
-- @param value [Any value to compare with, converted to a string]
function ActiveRecord.Query:where_gte(key, value)
  self:where_raw(self:quote_column(key)..' >= ?', { value })
end

--- Adds a "column <= value" condition.
-- @param key [String column name]
-- @param value [Any value to compare with, converted to a string]
function ActiveRecord.Query:where_lte(key, value)
  self:where_raw(self:quote_column(key)..' <= ?', { value })
end

--- Adds a column to the ORDER BY clause.
-- ```
-- query:order('id')              -- ORDER BY id ASC
-- query:order({ asc = 'name' })  -- ORDER BY name ASC
-- query:order({ desc = 'name' }) -- ORDER BY name DESC
-- ```
-- @param key [String/Map column name (sorted in ascending order), or a hash with the
--   column name stored under the 'asc' or 'desc' key]
function ActiveRecord.Query:order(key)
  local order_list = self.order_list

  if isstring(key) then
    order_list[#order_list + 1] = self:quote_column(key)..' ASC'
  elseif istable(key) then
    if key['asc'] then
      order_list[#order_list + 1] = self:quote_column(key['asc'])..' ASC'
    elseif key['desc'] then
      order_list[#order_list + 1] = self:quote_column(key['desc'])..' DESC'
    end
  end
end

--- Sets the function that is called once the query has been run.
-- @param callback [Function receives the result rows, the SQL string and the time the
--   query took in seconds]
function ActiveRecord.Query:callback(callback)
  self._callback = callback
end

--- Adds a column to the list of columns to select. All columns are selected if none
-- are added.
-- @param field_name [String column name]
function ActiveRecord.Query:select(field_name)
  local select_list = self.select_list

  select_list[#select_list + 1] = self:quote_column(field_name)
end

--- Marks a column to be dropped by a 'change' query.
-- @param field_name [String column name]
function ActiveRecord.Query:remove(field_name)
  local remove_column_list = self.remove_column_list

  remove_column_list[#remove_column_list + 1] = self:quote_column(field_name)
end

--- Marks a column to be renamed by a 'change' query.
-- @param what [String current column name]
-- @param into [String new column name]
function ActiveRecord.Query:rename(what, into)
  local rename_list = self.rename_list

  rename_list[#rename_list + 1] = { self:quote_column(what), self:quote_column(into) }
end

--- Sets the value of a column for an 'insert' query.
-- @param key [String column name]
-- @param value [Any value to insert, converted to a string]
function ActiveRecord.Query:insert(key, value)
  local insert_list = self.insert_list

  insert_list[#insert_list + 1] = { key, value }
end

--- Sets the new value of a column for an 'update' query.
-- @param key [String column name]
-- @param value [Any new value, converted to a string]
function ActiveRecord.Query:update(key, value)
  local update_list = self.update_list

  update_list[#update_list + 1] = { key, value }
end

--- Adds a column definition to a 'create' or 'change' query.
-- @param key [String column name]
-- @param value [String SQL definition of the column, e.g. 'varchar(255) NOT NULL']
function ActiveRecord.Query:create(key, value)
  local create_list = self.create_list

  create_list[#create_list + 1] = { self:quote_column(key), value }
end

--- Sets the column used for the PRIMARY KEY clause of a 'create' query.
-- @param key [String column name]
function ActiveRecord.Query:set_primary_key(key)
  self.prim_key = self:quote_column(key)
end

--- Limits the amount of rows affected by a 'select' or 'delete' query.
-- @param value [Number]
function ActiveRecord.Query:limit(value)
  self._limit = value
end

--- Sets the amount of rows that a 'select' query skips. Without #limit every row after
-- them is returned; the query then carries the largest LIMIT every database accepts, since
-- SQLite and MySQL do not take an OFFSET on its own.
-- @param value [Number]
function ActiveRecord.Query:offset(value)
  self._offset = value
end

--- Sets whether a 'create' query drops an existing table first. Without it, and without
-- #if_not_exists, creating a table that exists already fails.
-- @param overwrite [Boolean]
function ActiveRecord.Query:overwrite(overwrite)
  self._overwrite = overwrite
end

--- Sets whether a 'create' query leaves an existing table alone (CREATE TABLE IF NOT
-- EXISTS) instead of failing.
-- @param if_not_exists [Boolean]
function ActiveRecord.Query:if_not_exists(if_not_exists)
  self._if_not_exists = if_not_exists
end

--- Sets whether a 'drop' query ignores a missing table (DROP TABLE IF EXISTS) instead
-- of failing.
-- @param if_exists [Boolean]
function ActiveRecord.Query:if_exists(if_exists)
  self._if_exists = if_exists
end

local function build_where(query_obj)
  local where_list = query_obj.where_list
  local conditions = {}

  for i = 1, #where_list do
    local entry = where_list[i]
    local condition, values = entry[1], entry[2]

    if values then
      local n = 0

      condition = gsub(condition, '%?', function()
        n = n + 1
        return query_obj:bind(values[n])
      end)
    end

    conditions[#conditions + 1] = condition
  end

  return concat(conditions, ' AND ')
end

local function build_select_query(query_obj)
  local select_list = query_obj.select_list
  local where_list = query_obj.where_list
  local order_list = query_obj.order_list
  local limit, offset = query_obj._limit, query_obj._offset
  local query_string = { 'SELECT ' }

  if !istable(select_list) or #select_list == 0 then
    query_string[2] = ' *'
  else
    query_string[2] = ' '..concat(select_list, ', ')
  end

  if isstring(query_obj.table_name) then
    query_string[3] = ' FROM '..query_obj:quote_column(query_obj.table_name)..' '
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if istable(where_list) and #where_list > 0 then
    query_string[#query_string + 1] = ' WHERE '
    query_string[#query_string + 1] = build_where(query_obj)
  end

  if istable(order_list) and #order_list > 0 then
    query_string[#query_string + 1] = ' ORDER BY '
    query_string[#query_string + 1] = concat(order_list, ', ')
  end

  if isnumber(limit) then
    query_string[#query_string + 1] = ' LIMIT '
    query_string[#query_string + 1] = limit
  end

  if isnumber(offset) then
    if !isnumber(limit) then
      query_string[#query_string + 1] = ' LIMIT 9223372036854775807'
    end

    query_string[#query_string + 1] = ' OFFSET '
    query_string[#query_string + 1] = offset
  end

  return concat(query_string)
end

local function build_insert_query(query_obj)
  local insert_list = query_obj.insert_list
  local key_list = {}
  local value_list = {}
  local quoted_table

  if isstring(query_obj.table_name) then
    quoted_table = query_obj:quote_column(query_obj.table_name)
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  for i = 1, #insert_list do
    local entry = insert_list[i]

    key_list[i] = query_obj:quote_column(entry[1])
    value_list[i] = query_obj:bind(entry[2])
  end

  if #key_list == 0 then
    return
  end

  return 'INSERT INTO '..quoted_table..' ('..concat(key_list, ', ')..') VALUES ('..concat(value_list, ', ')..')'
end

local function build_update_query(query_obj)
  local update_list = query_obj.update_list
  local where_list = query_obj.where_list
  local query_string = { 'UPDATE ' }

  if isstring(query_obj.table_name) then
    query_string[2] = query_obj:quote_column(query_obj.table_name)
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if istable(update_list) and #update_list > 0 then
    local assignments = {}

    query_string[3] = ' SET'

    for i = 1, #update_list do
      local entry = update_list[i]

      assignments[i] = entry[1]..' = '..query_obj:bind(entry[2])
    end

    query_string[4] = ' '..concat(assignments, ', ')
  end

  if istable(where_list) and #where_list > 0 then
    query_string[#query_string + 1] = ' WHERE '
    query_string[#query_string + 1] = build_where(query_obj)
  end

  return concat(query_string)
end

local function build_delete_query(query_obj)
  local where_list = query_obj.where_list
  local query_string = { 'DELETE FROM ' }

  if isstring(query_obj.table_name) then
    query_string[2] = query_obj:quote_column(query_obj.table_name)
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if istable(where_list) and #where_list > 0 then
    query_string[3] = ' WHERE '
    query_string[4] = build_where(query_obj)
  end

  if isnumber(query_obj._limit) then
    query_string[#query_string + 1] = ' LIMIT '
    query_string[#query_string + 1] = query_obj._limit
  end

  return concat(query_string)
end

local function build_drop_query(query_obj)
  if !isstring(query_obj.table_name) then
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  local prefix = query_obj._if_exists and 'DROP TABLE IF EXISTS ' or 'DROP TABLE '

  return prefix..query_obj:quote_column(query_obj.table_name)
end

local function build_truncate_query(query_obj)
  if !isstring(query_obj.table_name) then
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  return 'TRUNCATE TABLE  '..query_obj:quote_column(query_obj.table_name)
end

local function build_create_query(query_obj)
  local create_list = query_obj.create_list
  local query_string = { 'DROP TABLE IF EXISTS ' }

  if !query_obj._overwrite then
    query_string[1] = query_obj._if_not_exists and 'CREATE TABLE IF NOT EXISTS ' or 'CREATE TABLE '
  end

  if isstring(query_obj.table_name) then
    query_string[2] = query_obj:quote_column(query_obj.table_name)
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if query_obj._overwrite then
    query_string[3] = ';\nCREATE TABLE '..query_obj:quote_column(query_obj.table_name)
  end

  query_string[#query_string + 1] = ' ('

  if istable(create_list) and #create_list > 0 then
    local is_sqlite = ActiveRecord.adapter.class_name:lower() == 'sqlite'
    local columns = {}

    for i = 1, #create_list do
      local entry = create_list[i]
      local definition = entry[2]

      if is_sqlite then
        definition = gsub(definition, 'AUTO_INCREMENT', ''):gsub('AUTOINCREMENT', ''):gsub('INT ', 'INTEGER ')
      end

      columns[i] = entry[1]..' '..definition
    end

    query_string[#query_string + 1] = ' '..concat(columns, ', ')
  end

  if isstring(query_obj.prim_key) and ActiveRecord.adapter_name != 'pg' then
    query_string[#query_string + 1] = ', PRIMARY KEY'
    query_string[#query_string + 1] = ' ('..query_obj.prim_key..')'
  end

  query_string[#query_string + 1] = ' )'

  if query_obj.options then
    query_string[#query_string + 1] = ' '..query_obj.options
  end

  return concat(query_string)
end

local function build_change_query(query)
  if !isstring(query.table_name) then
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  local table_name = query:quote_column(query.table_name)
  local remove_column_list = query.remove_column_list
  local rename_list = query.rename_list
  local create_list = query.create_list
  local clauses = {}
  local n = 0

  for i = 1, #remove_column_list do
    n = n + 1
    clauses[n] = 'DROP COLUMN '..remove_column_list[i]
  end

  for i = 1, #rename_list do
    local entry = rename_list[i]

    n = n + 1
    clauses[n] = 'RENAME COLUMN '..entry[1]..' TO '..entry[2]
  end

  for i = 1, #create_list do
    local entry = create_list[i]

    n = n + 1
    clauses[n] = 'ADD '..entry[1]..' '..entry[2]
  end

  if n == 0 then return end

  -- SQLite takes a single change per ALTER TABLE statement.
  if ActiveRecord.adapter:is_sqlite() then
    local prefix = 'ALTER TABLE '..table_name..' '
    local statements = {}

    for i = 1, n do
      statements[i] = prefix..clauses[i]
    end

    return concat(statements, ';\n')
  end

  return 'ALTER TABLE '..table_name..' '..concat(clauses, ', ')
end

--- Builds the SQL string of the query and hands it to the adapter, along with the values
-- of its bind parameters.
-- @param queue_query=false [Boolean put the query into the adapter's queue instead of
--   running it right away]
-- @return [Any whatever the query callback returns if the adapter ran the query
--   synchronously, nothing otherwise]
function ActiveRecord.Query:execute(queue_query)
  local query_string = nil
  local query_type = string.lower(self.query_type)
  local adapter = ActiveRecord.adapter

  self.bindings = {}

  adapter:append_query(self, query_type, queue_query)

  if query_type == 'select' then
    query_string = build_select_query(self)
  elseif query_type == 'insert' then
    query_string = build_insert_query(self)
  elseif query_type == 'update' then
    query_string = build_update_query(self)
  elseif query_type == 'delete' then
    query_string = build_delete_query(self)
  elseif query_type == 'drop' then
    query_string = build_drop_query(self)
  elseif query_type == 'truncate' then
    query_string = build_truncate_query(self)
  elseif query_type == 'create' then
    query_string = build_create_query(self)
  elseif query_type == 'change' then
    query_string = build_change_query(self)
  end

  local hooked = adapter:append_query_string(self, query_string, query_type)

  if isstring(hooked) then
    query_string = hooked
  end

  if isstring(query_string) then
    query_string = query_string:ensure_end(';')
    query_string = query_string:gsub(' ;', ';'):gsub('  ', ' ')

    local bindings = queries_with_bindings[query_type] and self.bindings or nil

    if !queue_query then
      return adapter:raw_query(query_string, self._callback, query_type, bindings)
    else
      return adapter:queue(query_string, self._callback, query_type, bindings)
    end
  end
end
