--[[
  mysql - 2.0.0
  A simple Database wrapper for Garry's Mod.

  Alexander Grist-Hucker
  http://www.alexgrist.com

  Meow the Cat
  https://teslacloud.net
--]]

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
-- Only PostgreSQL is supported; on MySQL instructions are printed instead.
-- @param settings [Map database settings: host, user, port, password and database]
function ActiveRecord.Database:setup(settings)
  local adapter = ActiveRecord.adapter
  adapter:sync(true)
  if adapter:is_postgres() then
    ActiveRecord.adapter:connect { host = settings.host, user = settings.user, port = settings.port, password = settings.password, database = "postgres" }
    local query = ActiveRecord.adapter:raw_query(txt([[
      DO
      $do$
      DECLARE
        _db TEXT := ']]..settings.database..[[';
      BEGIN
        CREATE EXTENSION IF NOT EXISTS dblink;
        IF EXISTS (SELECT 1 FROM pg_database WHERE datname = ']]..settings.database..[[') THEN
          RAISE NOTICE 'Database already exists';
        ELSE
          PERFORM dblink_exec('dbname=' || current_database(), 'CREATE DATABASE ' || _db);
        END IF;
      END
      $do$;
    ]]), function(result, query_str, time)
      print_query('Create Database ('..time..'s)', 'Success!')
      print 'Please restart your server for changes to take effect!'
    end)
  elseif adapter:is_mysql() then
    ErrorNoHalt('MySQL does not support automatic database creation (yet), sorry!\n')
    ErrorNoHalt('Please go to your MySQL terminal and use this to create the database:\nmysql> create database '..settings.database..'\n(without the "mysql>" part)\n')
  end
  ActiveRecord.adapter:disconnect()
  ActiveRecord.adapter:sync(false)
end

--- Drops the database named in the settings and disconnects the adapter afterward.
-- Connects to the 'template1' database to do so.
-- @param settings [Map database settings: host, user, port, password and database]
function ActiveRecord.Database:drop_database(settings)
  ActiveRecord.adapter:sync(true)
  ActiveRecord.adapter:connect { host = settings.host, user = settings.user, port = settings.port, password = settings.password, database = "template1" }
  local query = ActiveRecord.adapter:raw_query("DROP DATABASE "..settings.database..";", function(result, query_str, time)
    print_query('Drop Database ('..time..'s)', query_str)
  end)
  ActiveRecord.adapter:disconnect()
  ActiveRecord.adapter:sync(false)
end

--- Disconnects the active adapter from the database.
-- @param settings=nil [Map unused]
function ActiveRecord.Database:destroy(settings)
  ActiveRecord.adapter:disconnect()
end

timer.Create('ActiveRecord::Database#think', 1, 0, function()
  ActiveRecord.adapter:think()
end)
