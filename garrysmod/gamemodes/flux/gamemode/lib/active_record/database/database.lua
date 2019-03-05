--[[
  mysql - 2.0.0
  A simple Database wrapper for Garry's Mod.

  Alexander Grist-Hucker
  http://www.alexgrist.com

  Meow the Cat
  https://teslacloud.net
--]]

class 'ActiveRecord::Database'

function ActiveRecord.Database:select(table_name)
  return ActiveRecord.Query.new(table_name, 'select')
end

function ActiveRecord.Database:insert(table_name)
  return ActiveRecord.Query.new(table_name, 'insert')
end

function ActiveRecord.Database:update(table_name)
  return ActiveRecord.Query.new(table_name, 'update')
end

function ActiveRecord.Database:delete(table_name)
  return ActiveRecord.Query.new(table_name, 'delete')
end

function ActiveRecord.Database:drop(table_name)
  return ActiveRecord.Query.new(table_name, 'drop')
end

function ActiveRecord.Database:truncate(table_name)
  return ActiveRecord.Query.new(table_name, 'truncate')
end

function ActiveRecord.Database:create(table_name)
  return ActiveRecord.Query.new(table_name, 'create')
end

function ActiveRecord.Database:change(table_name)
  return ActiveRecord.Query.new(table_name, 'change')
end

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
    ErrorNoHalt('Please go to your MySQL temrminal and use this to create database:\nmysql> create database '..settings.database..'\n(without the "mysql>" part)\n')
  end
  ActiveRecord.adapter:disconnect()
  ActiveRecord.adapter:sync(false)
end

function ActiveRecord.Database:drop_database(settings)
  ActiveRecord.adapter:sync(true)
  ActiveRecord.adapter:connect { host = settings.host, user = settings.user, port = settings.port, password = settings.password, database = "template1" }
  local query = ActiveRecord.adapter:raw_query("DROP DATABASE "..settings.database..";", function(result, query_str, time)
    print_query('Drop Database ('..time..'s)', query_str)
  end)
  ActiveRecord.adapter:disconnect()
  ActiveRecord.adapter:sync(false)
end

function ActiveRecord.Database:destroy(settings)
  ActiveRecord.adapter:disconnect()
end

timer.Create('ActiveRecord::Database#think', 1, 0, function()
  ActiveRecord.adapter:think()
end)
