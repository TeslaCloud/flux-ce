--- Entry point of the query builder. Each of its methods starts an `ActiveRecord::Query`
-- of one type (select, insert, update, delete, create, change, drop or truncate) on a
-- table; the query is then set up through its own methods and run with
-- `ActiveRecord::Query#execute`. Models and the schema statements are built on top of it,
-- so it is only needed directly for tables that have no model. The class is used as it
-- is, without creating objects of it.
--
-- It also creates and drops the database itself for the `flux db:create` and
-- `flux db:drop` tasks, and makes the adapter work off its queue of deferred queries.
--
-- Based off mysql from Alex Grist.

class 'ActiveRecord::Database'

--- Starts a SELECT query on a table.
-- Query methods do not chain; configure the query and then run it with #execute.
-- ```
-- local query = ActiveRecord.Database:select('ar_metadata')
--   query:where('key', 'version')
--   query:limit(1)
--   query:callback(function(result, query_str, time)
--     if istable(result) and #result > 0 then
--       print(result[1].value)
--     end
--   end)
-- query:execute()
-- ```
-- @param table_name [String]
-- @return [ActiveRecord::Query]
function ActiveRecord.Database:select(table_name)
  return ActiveRecord.Query.new(table_name, 'select')
end

--- Starts an INSERT query on a table.
-- ```
-- local query = ActiveRecord.Database:insert('ar_metadata')
--   query:insert('key', 'version')
--   query:insert('value', 20190309120000)
-- query:execute()
-- ```
-- @param table_name [String]
-- @return [ActiveRecord::Query]
function ActiveRecord.Database:insert(table_name)
  return ActiveRecord.Query.new(table_name, 'insert')
end

--- Starts an UPDATE query on a table.
-- ```
-- local query = ActiveRecord.Database:update('ar_metadata')
--   query:where('key', 'version')
--   query:update('value', 20190309120000)
-- query:execute()
-- ```
-- @param table_name [String]
-- @return [ActiveRecord::Query]
function ActiveRecord.Database:update(table_name)
  return ActiveRecord.Query.new(table_name, 'update')
end

--- Starts a DELETE query on a table.
-- @param table_name [String]
-- @return [ActiveRecord::Query]
function ActiveRecord.Database:delete(table_name)
  return ActiveRecord.Query.new(table_name, 'delete')
end

--- Starts a DROP TABLE query.
-- @param table_name [String]
-- @return [ActiveRecord::Query]
function ActiveRecord.Database:drop(table_name)
  return ActiveRecord.Query.new(table_name, 'drop')
end

--- Starts a TRUNCATE TABLE query.
-- @param table_name [String]
-- @return [ActiveRecord::Query]
function ActiveRecord.Database:truncate(table_name)
  return ActiveRecord.Query.new(table_name, 'truncate')
end

--- Starts a CREATE TABLE query. The returned query has a method for every column type
-- of the current adapter (query:string, query:integer, ...).
-- @param table_name [String]
-- @return [ActiveRecord::Query]
-- @see [create_table]
function ActiveRecord.Database:create(table_name)
  return ActiveRecord.Query.new(table_name, 'create')
end

--- Starts an ALTER TABLE query. The returned query has a method for every column type
-- of the current adapter, which adds a column of that type.
-- @param table_name [String]
-- @return [ActiveRecord::Query]
-- @see [change_table]
function ActiveRecord.Database:change(table_name)
  return ActiveRecord.Query.new(table_name, 'change')
end

--- Creates the database named in the settings and disconnects the adapter afterward.
-- Only PostgreSQL is supported; on MySQL and SQLite an error says what to do instead.
-- @param settings [Map database settings: host, user, port, password and database]
function ActiveRecord.Database:setup(settings)
  local adapter = ActiveRecord.adapter

  if adapter:is_mysql() then
    error('ActiveRecord - MySQL databases are not created automatically: create it in a MySQL client with '
      ..'CREATE DATABASE '..tostring(settings.database)..';', 0)
  elseif !adapter:is_postgres() then
    error('ActiveRecord - SQLite has no database to create: its tables live in the sv.db file, where '
      ..'db:migrate or the start of the server creates them.', 0)
  end

  adapter:sync(true)
  ActiveRecord.adapter:connect {
    host = settings.host,
    user = settings.user,
    port = settings.port,
    password = settings.password,
    database = 'postgres'
  }

    local database = ActiveRecord.adapter:quote(settings.database)

    ActiveRecord.adapter:raw_query(txt([[
      DO
      $do$
      DECLARE
        _db TEXT := ]]..database..[[;
      BEGIN
        CREATE EXTENSION IF NOT EXISTS dblink;
        IF EXISTS (SELECT 1 FROM pg_database WHERE datname = _db) THEN
          RAISE NOTICE 'Database already exists';
        ELSE
          PERFORM dblink_exec('dbname=' || current_database(), 'CREATE DATABASE ' || quote_ident(_db));
        END IF;
      END
      $do$;
    ]]), function(_result, _query_str, time)
      print_query('Create Database ('..time..'s)', 'Success!')
      print 'Please restart your server for changes to take effect!'
    end)

  ActiveRecord.adapter:disconnect()
  ActiveRecord.adapter:sync(false)
end

--- Drops the database named in the settings and disconnects the adapter afterward.
-- Only PostgreSQL is supported, through its 'template1' database; on MySQL and SQLite an
-- error says what to do instead.
-- @param settings [Map database settings: host, user, port, password and database]
function ActiveRecord.Database:drop_database(settings)
  local adapter = ActiveRecord.adapter

  if adapter:is_mysql() then
    error('ActiveRecord - MySQL databases are not dropped automatically: drop it in a MySQL client with '
      ..'DROP DATABASE '..tostring(settings.database)..';', 0)
  elseif !adapter:is_postgres() then
    error('ActiveRecord - SQLite has no database to drop: to wipe its tables, delete the sv.db file while the '
      ..'server is stopped, or enter ar_recreate_schema twice in the server console.', 0)
  end

  ActiveRecord.adapter:sync(true)
  ActiveRecord.adapter:connect {
    host = settings.host,
    user = settings.user,
    port = settings.port,
    password = settings.password,
    database = 'template1'
  }
  ActiveRecord.adapter:raw_query(
    'DROP DATABASE '..ActiveRecord.adapter:quote_name(settings.database)..';',
    function(_result, query_str, time)
      print_query('Drop Database ('..time..'s)', query_str)
    end
  )

  ActiveRecord.adapter:disconnect()
  ActiveRecord.adapter:sync(false)
end

--- Disconnects the active adapter from the database.
-- @param _settings=nil [Map unused]
function ActiveRecord.Database:destroy(_settings)
  ActiveRecord.adapter:disconnect()
end

timer.Create('ActiveRecord::Database#think', 1, 0, function()
  ActiveRecord.adapter:think()
end)
