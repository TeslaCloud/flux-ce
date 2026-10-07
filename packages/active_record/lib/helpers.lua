--- Formats a schema statement and its arguments for the migration output,
-- e.g. 'add_column("users", "role", "string")'.
-- @param command [String]
-- @param ... [Vararg arguments of the statement; functions are left out]
-- @return [String]
function ActiveRecord.format_command(command, ...)
  local parts = {}

  for i = 1, select('#', ...) do
    local arg = select(i, ...)

    if isstring(arg) then
      table.insert(parts, '"'..arg..'"')
    elseif istable(arg) then
      local inner = {}

      for k, v in pairs(arg) do
        if !isfunction(v) then
          table.insert(inner, (isnumber(k) and '' or k..' = ')..(isstring(v) and '"'..v..'"' or tostring(v)))
        end
      end

      table.sort(inner)
      table.insert(parts, '{ '..table.concat(inner, ', ')..' }')
    elseif arg != nil and !isfunction(arg) then
      table.insert(parts, tostring(arg))
    end
  end

  return command..'('..table.concat(parts, ', ')..')'
end

--- Runs a schema statement. Normally the statement is handed to the function of the
-- same name in ActiveRecord.SchemaStatements, timed and printed if a migration is
-- running. While a migration is being reverted through its #change, the statement is
-- recorded instead, so that its inverse can be run later.
-- @param command [String name of the statement, e.g. 'create_table']
-- @param ... [Vararg arguments of the statement]
-- @return [Any whatever the statement returns]
function ActiveRecord.ddl(command, ...)
  local recorder = ActiveRecord.Migration.current_recorder()

  if recorder then
    return recorder:record(command, ...)
  end

  local statement = ActiveRecord.SchemaStatements[command]

  if !statement then
    error('ActiveRecord - unknown schema statement \''..tostring(command)..'\'!', 0)
  end

  local migration = ActiveRecord.Migration.current_migration()

  if migration and command != 'execute_block' then
    local args = { n = select('#', ...), ... }

    return migration:say_with_time(ActiveRecord.format_command(command, ...), function()
      return statement(unpack(args, 1, args.n))
    end)
  end

  return statement(...)
end

--- Creates a database table. The 'id' primary key is added automatically.
-- ```
-- create_table('logs', function(t)
--   t:text 'body'
--   t:string { 'action', null = false }
--   t:timestamps()
-- end)
--
-- create_table('users', { force = true }, function(t) ... end)
-- ```
-- @param name [String table name]
-- @param options=nil [Map force (drop an existing table first), if_not_exists (leave an
--   existing table alone), id (false to not add a primary key), primary_key (name of the
--   primary key column, 'id' by default)]
-- @param callback=nil [Function receives the 'create' ActiveRecord::Query to define the
--   columns on]
function create_table(name, options, callback)
  return ActiveRecord.ddl('create_table', name, options, callback)
end

--- Drops a database table. In a migration's #change this is only reversible when the
-- columns are given, as in `drop_table('logs', function(t) t:text 'body' end)`.
-- @param name [String table name]
-- @param options=nil [Map if_exists (ignore a missing table)]
-- @param callback=nil [Function the column definition, for reverting the statement]
function drop_table(name, options, callback)
  return ActiveRecord.ddl('drop_table', name, options, callback)
end

--- Renames a database table.
-- @param name [String current table name]
-- @param new_name [String]
function rename_table(name, new_name)
  return ActiveRecord.ddl('rename_table', name, new_name)
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
  return ActiveRecord.ddl('change_table', name, callback)
end

--- Adds a column to an existing table.
-- ```
-- add_column('users', 'role', 'string', { default = '\'user\'' })
-- add_column('users', { 'banned', type = 'boolean', default = false })
-- ```
-- @param table_name [String table name]
-- @param name [String/Map column name, or a table holding the name at index 1, the
--   abstract column type under 'type' and the options as keys]
-- @param type=nil [String abstract column type, e.g. 'string', 'integer' or 'datetime']
-- @param options=nil [Map null (Boolean) and default (inserted into the SQL as is)]
function add_column(table_name, name, type, options)
  return ActiveRecord.ddl('add_column', table_name, name, type, options)
end

--- Removes a column from an existing table. Give the type to make it reversible.
-- @param table_name [String table name]
-- @param name [String column name]
-- @param type=nil [String abstract column type]
-- @param options=nil [Map column options]
function remove_column(table_name, name, type, options)
  return ActiveRecord.ddl('remove_column', table_name, name, type, options)
end

--- Renames a column of an existing table.
-- @param table_name [String table name]
-- @param name [String current column name]
-- @param new_name [String]
function rename_column(table_name, name, new_name)
  return ActiveRecord.ddl('rename_column', table_name, name, new_name)
end

--- Adds the 'created_at' and 'updated_at' columns to an existing table.
-- @param table_name [String]
-- @param options=nil [Map column options, e.g. { null = true }]
function add_timestamps(table_name, options)
  return ActiveRecord.ddl('add_timestamps', table_name, options)
end

--- Removes the 'created_at' and 'updated_at' columns from a table.
-- @param table_name [String]
-- @param options=nil [Map unused]
function remove_timestamps(table_name, options)
  return ActiveRecord.ddl('remove_timestamps', table_name, options)
end

--- Adds a reference column ('<name>_id'), its index and optionally a foreign key to an
-- existing table.
-- ```
-- add_reference('characters', 'user', { foreign_key = { on_delete = 'cascade' } })
-- ```
-- @param table_name [String]
-- @param name [String name of the referenced model, singular]
-- @param options=nil [Map the options of t:references]
function add_reference(table_name, name, options)
  return ActiveRecord.ddl('add_reference', table_name, name, options)
end

--- Removes a reference column along with its index and foreign key.
-- @param table_name [String]
-- @param name [String name of the referenced model, singular]
-- @param options=nil [Map column (defaults to '<name>_id')]
function remove_reference(table_name, name, options)
  return ActiveRecord.ddl('remove_reference', table_name, name, options)
end

--- Creates an index. The index is named '<table>_<columns>_index' if no name is given.
-- ```
-- add_index('users', 'steam_id')
-- add_index('characters', { 'user_id', 'name' }, { unique = true })
-- add_index { 'users', 'steam_id', unique = true }
-- ```
-- @param table_name [String/Map table name, or a table holding the table name at index
--   1, the column(s) at index 2 and the options as keys]
-- @param columns=nil [String/List<String> column name or a list of column names]
-- @param options=nil [Map name, unique, length, using, where and if_not_exists]
function add_index(table_name, columns, options)
  return ActiveRecord.ddl('add_index', table_name, columns, options)
end

--- Drops an index.
-- ```
-- remove_index('users', 'steam_id')
-- remove_index('users', { name = 'users_steam_id_index' })
-- ```
-- @param table_name [String]
-- @param options [String/List<String>/Map column name, list of column names, or a table
--   with name or column(s) and optionally if_exists]
function remove_index(table_name, options)
  return ActiveRecord.ddl('remove_index', table_name, options)
end

--- Drops an index by name.
-- @param index_name [String]
-- @param table_name [String table the index belongs to]
function drop_index(index_name, table_name)
  return ActiveRecord.ddl('remove_index', table_name, { name = index_name })
end

--- Adds a foreign key constraint.
-- ```
-- add_foreign_key('characters', 'users')
-- add_foreign_key('characters', 'users', { column = 'owner_id', on_delete = 'cascade' })
-- ```
-- @param from_table [String table that holds the key]
-- @param to_table [String table the key refers to]
-- @param options=nil [Map column (defaults to '<singular of to_table>_id'), primary_key
--   ('id' by default), on_delete ('cascade', 'nullify' or 'restrict') and name]
function add_foreign_key(from_table, to_table, options)
  return ActiveRecord.ddl('add_foreign_key', from_table, to_table, options)
end

--- Drops a foreign key constraint.
-- @param from_table [String table that holds the key]
-- @param to_table [String/Map table the key refers to, or the options]
-- @param options=nil [Map column or name of the constraint]
function remove_foreign_key(from_table, to_table, options)
  return ActiveRecord.ddl('remove_foreign_key', from_table, to_table, options)
end

--- Adds a foreign key constraint along with an index on the key column.
-- @param args [Map table_name, key, foreign_table and foreign_key, optionally cascade
--   (Boolean, adds ON DELETE CASCADE) and name (name of the constraint)]
function create_reference(args)
  return ActiveRecord.ddl('create_reference', args)
end

--- Adds a PRIMARY KEY constraint named '<table_name>_pkey' to a table.
-- @param table_name [String]
-- @param key [String column name]
function create_primary_key(table_name, key)
  return ActiveRecord.ddl('create_primary_key', table_name, key)
end

--- Runs a raw SQL statement. Not reversible.
-- @param sql [String]
function execute(sql)
  return ActiveRecord.ddl('execute', sql)
end

local function running_migration(name)
  local migration = ActiveRecord.Migration.current_migration()

  if !migration then
    error(name..' can only be used inside of a running migration!', 0)
  end

  return migration
end

--- Lets a migration's #change run code that differs between migrating and reverting.
-- Shorthand for ActiveRecord::Migration#reversible on the running migration.
-- ```
-- reversible(function(dir)
--   dir:up(function() execute("UPDATE users SET role = 'user'") end)
--   dir:down(function() execute("UPDATE users SET role = NULL") end)
-- end)
-- ```
-- @param callback [Function receives the direction helper]
function reversible(callback)
  return running_migration('reversible'):reversible(callback)
end

--- Runs the inverse of the statements made inside of the function. Shorthand for
-- ActiveRecord::Migration#revert on the running migration.
-- @param callback [Function/ActiveRecord::Migration]
function revert(callback)
  return running_migration('revert'):revert(callback)
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
