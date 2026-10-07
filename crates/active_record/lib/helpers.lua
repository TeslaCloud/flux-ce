--- Creates a database table. An existing table with the same name is dropped first,
-- unless the callback calls t:overwrite(false).
-- ```
-- create_table('logs', function(t)
--   t:primary_key 'id'
--   t:text 'body'
--   t:string { 'action', null = false }
-- end)
-- ```
-- @param name [String table name]
-- @param callback [Function receives the 'create' ActiveRecord::Query to define the
--   columns on]
function create_table(name, callback)
  local query = ActiveRecord.Database:create(name)
    query:overwrite(true)
    callback(query)
    query:callback(function(result, query_str, time)
      print_query('Create Table ('..time..'s)', query_str)
    end)
  query:execute()
end

--- Drops a database table.
-- @param name [String table name]
function drop_table(name)
  local query = ActiveRecord.Database:drop(name)
    query:callback(function(result, query, time)
      print_query('Drop Table ('..time..'s)', query)
    end)
  return query:execute()
end

--- Alters an existing database table.
-- ```
-- change_table('users', function(t)
--   t:rename('name', 'nickname')
--   t:remove('banned')
--   t:integer 'playtime'
-- end)
-- ```
-- @param name [String table name]
-- @param callback [Function receives the 'change' ActiveRecord::Query to describe the
--   changes on]
function change_table(name, callback)
  local query = ActiveRecord.Database:change(name)
    callback(query)
    query:callback(function(result, query_str, time)
      print_query('Change Table ('..time..'s)', query_str)
    end)
  query:execute()
end

--- Renames a column of an existing table.
-- @param table [String table name]
-- @param name [String current column name]
-- @param new_name [String]
function rename_column(table, name, new_name)
  change_table(table, function(t)
    t:rename(name, new_name)
  end)
end

--- Removes a column from an existing table.
-- @param table [String table name]
-- @param name [String column name]
function remove_column(table, name)
  change_table(table, function(t)
    t:remove(name)
  end)
end

--- Adds a column to an existing table.
-- ```
-- add_column('users', { 'role', type = 'string', default = '\'user\'' })
-- add_column('users', { 'banned', type = 'boolean', default = false })
-- ```
-- @param table [String table name]
-- @param args [Hash column name at index 1, the abstract column type under 'type', and
--   optionally null (Boolean) and default (inserted into the SQL as is)]
function add_column(table, args)
  change_table(table, function(t)
    t[args.type](t, args)
  end)
end

--- Creates an index, unless an index with the same name is already recorded in the
-- metadata. The index is named '<table>_<columns>_index' if no name is given.
-- ```
-- add_index { 'users', 'steam_id' }
-- add_index { 'characters', { 'user_id', 'name' }, unique = true }
-- ```
-- @param args [Hash table name at index 1 and a column name or an Array of column names
--   at index 2; optional keys are name, unique, length, using, where and if_not_exists]
function add_index(args)
  if !isstring(args[1]) or !args[2] then return end

  local cols = istable(args[2]) and args[2] or { args[2] }
  local len = args['length']
  local index_name = args['name'] or args[1]..'_'..table.concat(cols, '_')..'_index'
  local postgres = ActiveRecord.adapter:is_postgres()
  local sqlite = ActiveRecord.adapter:is_sqlite()

  if ActiveRecord.metadata.indexes[index_name] then return end

  local query = 'CREATE '..(args['unique'] == true and 'UNIQUE ' or '')..'INDEX '

  if args['if_not_exists'] then
    query = query..' IF NOT EXISTS '
  end

  query = query..index_name

  query = query..' ON '..args[1]

  local function _columns(query)
    query = query..' ('

    for k, v in ipairs(cols) do
      query = query..v

      if len and !sqlite then
        query = query..'('..(istable(len) and len[v] or len)..')'
      end

      if k != #cols then
        query = query..', '
      end
    end

    query = query..')'

    return query
  end

  if !postgres then
    query = _columns(query)
  end

  if !sqlite then
    query = query..' USING '..(args['using'] or (postgres and 'btree' or 'BTREE'))
  end

  if postgres then
    query = _columns(query)
  end

  if args['where'] then
    query = query..' WHERE '..args['where']
  end

  query = query..';'

  ActiveRecord.metadata.indexes[index_name] = args

  ActiveRecord.adapter:raw_query(query, function(results, query_str, time)
    print_query('Add Index ('..time..'s)', query_str)
  end)
end

--- Drops an index and removes it from the metadata.
-- @param index_name [String]
-- @param table_name [String table the index belongs to]
function drop_index(index_name, table_name)
  ActiveRecord.metadata.indexes[index_name] = nil

  ActiveRecord.adapter:raw_query('DROP INDEX IF EXISTS '..index_name..' ON '..table_name..';', function(results, query_str, time)
    print_query('Drop Index ('..time..'s)', query_str)
  end)
end

--- Adds a foreign key constraint, along with an index on the key column. Does nothing
-- if a constraint with the same name is already recorded in the metadata.
-- ```
-- create_reference {
--   table_name = 'characters', key = 'user_id',
--   foreign_table = 'users', foreign_key = 'id',
--   cascade = true
-- }
-- ```
-- @param args [Hash table_name, key, foreign_table and foreign_key, optionally cascade
--   (Boolean, adds ON DELETE CASCADE) and name (name of the constraint)]
function create_reference(args)
  local table_name, key, foreign_table, foreign_key, cascade = args.table_name, args.key, args.foreign_table, args.foreign_key, args.cascade

  add_index { table_name, key }

  local constraint_name = args.name or 'ar_'..util.CRC(key..foreign_key..table_name..foreign_table)

  if ActiveRecord.metadata.references[constraint_name] then return end

  local query = 'ALTER TABLE '..table_name
    ..' ADD CONSTRAINT '..constraint_name
    ..' FOREIGN KEY ('..key..') REFERENCES '
    ..foreign_table..'('..foreign_key..')'
  query = query..(cascade and ' ON DELETE CASCADE;' or ';')

  ActiveRecord.metadata.references[constraint_name] = args

  ActiveRecord.adapter:raw_query(query, function(result, query_str, time)
    print_query('Create Reference ('..time..'s)', query_str)
  end)
end

--- Adds a PRIMARY KEY constraint named '<table_name>_pkey' to a table, unless it is
-- already recorded in the metadata.
-- @param table_name [String]
-- @param key [String column name]
function create_primary_key(table_name, key)
  local pkey_name = table_name..'_pkey'

  if ActiveRecord.metadata.prim_keys[pkey_name] then return end

  ActiveRecord.metadata.prim_keys[pkey_name] = { table_name, key }
  ActiveRecord.adapter:raw_query('ALTER TABLE '..table_name
    ..' ADD CONSTRAINT '..pkey_name
    ..' PRIMARY KEY ('..key..');', function(result, query_str, time)
      print_query('Create Primary Key ('..time..'s)', query_str)
  end)
end

--- Converts a unix timestamp to an ISO 8601 date-time string in UTC,
-- e.g. '2019-03-09T12:00:00Z'.
-- @param unix_time [Number]
-- @return [String]
function to_datetime(unix_time)
  return DateTime:iso(unix_time)
end

--- Converts a unix timestamp to a 'YYYYMMDDHHMMSS' string in the server's local time.
-- @param unix_time [Number]
-- @return [String]
function to_timestamp(unix_time)
  return os.date('%Y%m%d%H%M%S', unix_time)
end

do
  local indent_level = 1

  --- Returns the indentation level used when printing queries to the console.
  -- @return [Number]
  function ar_get_indent()
    return indent_level
  end

  --- Sets the indentation level used when printing queries to the console.
  -- @param lvl=1 [Number]
  -- @return [Number new indentation level]
  function ar_set_indent(lvl)
    indent_level = lvl or 1
    return indent_level
  end

  --- Increases the indentation level used when printing queries by one.
  -- @return [Number new indentation level]
  function ar_add_indent()
    indent_level = indent_level + 1
    return indent_level
  end

  --- Decreases the indentation level used when printing queries by one.
  -- @return [Number new indentation level]
  function ar_sub_indent()
    indent_level = indent_level - 1
    return indent_level
  end

  --- Prints a query to the console at the current indentation level. Does nothing in
  -- production, unless Settings.debug_output_in_production is set.
  -- @param prefix [String label printed in front of the query, e.g. 'User Load (0.001s)']
  -- @param query [String text of the query]
  function print_query(prefix, query)
    if !IS_PRODUCTION or Settings.debug_output_in_production then
      MsgC(Color('cyan'), string.rep('  ', indent_level)..prefix..' ')
      MsgC(Color(100, 220, 100), query)
      Msg('\n')
    end
  end
end

--- Converts a 'YYYY-MM-DD HH:MM:SS' date-time string to a unix timestamp.
-- @param timestamp [String]
-- @return [Number]
function time_from_timestamp(timestamp)
  local yy, mm, dd, hh, m, ss = string.match(timestamp, '(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
  return os.time({
    year = yy,
    month = mm,
    day = dd,
    hour = hh,
    min = m,
    sec = ss
  })
end

--- Escapes a string for use inside an SQL string literal, using the current adapter.
-- @param str [String]
-- @return [String]
function sql_escape(str)
  return ActiveRecord.adapter:escape(str)
end

--- Reverts the escaping of a string read from the database, using the current adapter.
-- @param str [String]
-- @return [String]
function sql_unescape(str)
  return ActiveRecord.adapter:unescape(str)
end

--- Turns a string into an escaped, quoted SQL string literal, using the current adapter.
-- @param str [String]
-- @return [String]
function sql_quote(str)
  return ActiveRecord.adapter:quote(str)
end

--- Quotes an identifier such as a table or column name, using the current adapter.
-- @param str [String]
-- @return [String]
function sql_quote_name(str)
  return ActiveRecord.adapter:quote_name(str)
end
