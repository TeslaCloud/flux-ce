-- Store for later use.
local PACKAGE = PACKAGE

ActiveRecord.schema       = ActiveRecord.schema               or {}
ActiveRecord.db_settings  = DatabaseSettings[ENV['FLUX_ENV']] or DatabaseSettings['development'] or {}
ActiveRecord.adapter_name = ActiveRecord.db_settings.adapter  or 'sqlite'
ActiveRecord.metadata     = ActiveRecord.metadata             or {
  indexes     = {},
  references  = {},
  prim_keys   = {},
  adapter     = '',
  db_name     = ''
}

include 'generators/generator.lua'
include 'database/database.lua'
include 'database/query.lua'
include 'adapters/abstract.lua'
include 'database/queue.lua'
include 'migrator/migrator.lua'
include 'model.lua'
include 'validator.lua'
include 'base.lua'
include 'helpers.lua'
include 'commandline.lua'
include 'dumper.lua'

--- Registers a column in the in-memory schema, inserting a row into the 'ar_schema'
-- table if the column is new. Throws an error if ActiveRecord is not ready yet.
-- @param table_name [String database table the column belongs to]
-- @param column_name [String]
-- @param type [String abstract column type, e.g. 'string', 'integer' or 'datetime']
function ActiveRecord.add_to_schema(table_name, column_name, type)
  if !ActiveRecord.ready then
    error('Attempt to edit the schema too early!')
  end

  local t = ActiveRecord.schema[table_name] or {}

  if t[column_name] then
    t[column_name] = { id = t[column_name].id, type = type }
  else
    local query = ActiveRecord.Database:insert('ar_schema')
      query:insert('table_name', table_name)
      query:insert('column_name', column_name)
      query:insert('abstract_type', type)
      query:insert('definition', ActiveRecord.adapter.types[type] or '')
    query:execute()

    t[column_name] = { id = -1, type = type }
  end

  ActiveRecord.schema[table_name] = t
end

--- Loads the stored schema from the 'ar_schema' table. Once loaded, marks ActiveRecord
-- as ready, populates the models and creates the tables queued by #define_model.
-- @warning [Internal]
function ActiveRecord.restore_schema()
  local query = ActiveRecord.Database:select('ar_schema')
    query:callback(function(result, query, time)
      print_query('Schema Restore ('..time..'s)', query)

      if istable(result) then
        for k, v in ipairs(result) do
          local t = ActiveRecord.schema[v.table_name] or {}
          v.id = tonumber(v.id) or 0
          t[v.column_name] = { id = v.id, type = v.abstract_type }
          ActiveRecord.schema[v.table_name] = t
        end
      end

      ActiveRecord.ready = true
      ActiveRecord.Model:populate()
      Flux.dev_print 'ActiveRecord - Ready!'
      ActiveRecord.Queue:run()
    end)
  query:execute()
end

--- Reads a value from the 'ar_metadata' key-value table.
-- Make sure to run this while the adapter is in "sync mode", since asynchronous
-- queries return nothing.
-- @param key [String]
-- @param default=nil [Any value to return if the key is not stored]
-- @return [String/Any stored value, or default if the key is missing]
function ActiveRecord.get_meta_key(key, default)
  local query = ActiveRecord.Database:select('ar_metadata')
    query:where('key', key)
    query:limit(1)
    query:callback(function(res, query_str, time)
      print_query('Meta Get ('..time..'s)', query_str)
      if istable(res) and #res > 0 then
        return res[1] and res[1].value or default
      end
      return default
    end)
  return query:execute()
end

--- Writes a value to the 'ar_metadata' key-value table, updating the row if the key
-- already exists.
-- @param key [String]
-- @param value [Any value to store, converted to a string]
function ActiveRecord.set_meta_key(key, value)
  local query = ActiveRecord.Database:select('ar_metadata')
    query:where('key', key)
    query:callback(function(res)
      if istable(res) and #res > 0 then
        local q = ActiveRecord.Database:update('ar_metadata')
          q:where('key', key)
          q:update('value', value)
          q:callback(function(r, query_str, time)
            print_query('Meta Update ('..time..'s)', query_str)
          end)
        q:execute()
      else
        local q = ActiveRecord.Database:insert('ar_metadata')
          q:insert('key', key)
          q:insert('value', value)
          q:callback(function(r, query_str, time)
            print_query('Meta Insert ('..time..'s)', query_str)
          end)
        q:execute()
      end
    end)
  query:execute()
end

--- Defines the database table of a model. Meant to be used in migrations.
-- The 'id' primary key and the 'created_at' / 'updated_at' columns are added
-- automatically. The table is created right away (replacing an existing table with the
-- same name), or queued until the schema is restored if ActiveRecord is not ready yet.
-- ```
-- ActiveRecord.define_model('users', function(t)
--   t:string { 'steam_id', null = false }
--   t:string { 'name', null = false }
--   t:integer 'playtime'
-- end)
-- ```
-- @param name [String table name, the lowercase plural of the model's class name]
-- @param callback [Function receives the table definition, which has a method for every
--   column type: primary_key, string, text, integer, float, decimal, datetime, timestamp,
--   time, date, binary, boolean and json]
function ActiveRecord.define_model(name, callback)
  local definition = function(t)
    t:primary_key 'id'
    callback(t)
    t:datetime { 'created_at', null = false }
    t:datetime { 'updated_at', null = false }
  end

  if ActiveRecord.ready then
    create_table(name, definition)
  else
    ActiveRecord.Queue:add(name, definition)
  end
end

-- Setup aliases for common adapters.
local adapter_aliases = {
  ['postgresql']  = 'pg',
  ['sqlite3']     = 'sqlite',
  ['mysql']       = 'mysqloo'
}

--- Loads the database adapter named in the config and connects it to the database.
-- Uses 'sqlite' if no adapter is named, and resolves the aliases 'postgresql', 'sqlite3'
-- and 'mysql' (the config's adapter field is rewritten in that case).
-- ```
-- ActiveRecord.establish_connection {
--   adapter = 'mysqloo', host = '127.0.0.1', port = 3306,
--   user = 'username', password = 'password', database = 'flux_dev'
-- }
-- ```
-- @param config [Map database settings as found in config/database.yml: adapter, host,
--   port, user, password, database, encoding, socket and flags]
function ActiveRecord.establish_connection(config)
  local adapter = isstring(config.adapter) and config.adapter:lower() or 'sqlite'

  if adapter_aliases[adapter] then
    adapter         = adapter_aliases[adapter]
    config.adapter  = adapter
  end

  local path = PACKAGE.__path__

  if file.Exists(path..'lib/adapters/'..adapter..'.lua', 'LUA') then
    include(path..'lib/adapters/'..adapter..'.lua')
  end

  ActiveRecord.adapter = (ActiveRecord.Adapters[adapter:capitalize()] or ActiveRecord.Adapters.Abstract).new()
  ActiveRecord.adapter:connect(config, ActiveRecord.Adapters.Abstract.on_connected)
end

--- Bootstraps ActiveRecord once the adapter is connected: creates the internal tables,
-- restores the schema, runs pending migrations and fires the 'ActiveRecordReady' hook.
-- @warning [Internal]
function ActiveRecord.on_connected()
  Flux.dev_print 'ActiveRecord - Connected to the database!'

  ActiveRecord.generate_tables()
  ActiveRecord.restore_schema()

  local class_name = ActiveRecord.adapter.class_name:lower()
  local db_version = ActiveRecord.get_meta_key('version', 0)
  local adapter = ActiveRecord.get_meta_key('adapter', class_name)

  if adapter != class_name then
    ActiveRecord.drop_schema(true)
    ActiveRecord.generate_tables()

    adapter = class_name
  end

  ActiveRecord.migrator = ActiveRecord.Migrator.new(db_version)
  ActiveRecord.migrator:run_migrations()

  ActiveRecord.set_meta_key('version', ActiveRecord.migrator.schema.version)
  ActiveRecord.set_meta_key('adapter', adapter)

  hook.Run('ActiveRecordReady')
end

--- Drops the internal 'ar_schema' and 'ar_metadata' tables and, unless told otherwise,
-- every table known to the schema. This destroys the stored data.
-- @param meta_only=false [Boolean only drop the internal tables]
function ActiveRecord.drop_schema(meta_only)
  if !meta_only then
    for k, v in pairs(ActiveRecord.schema) do
      drop_table(k)
    end
  end
  drop_table 'ar_schema'
  drop_table 'ar_metadata'
end

--- Drops all tables, recreates the internal ones and then restarts the current map.
-- This destroys all data stored in the database.
function ActiveRecord.recreate_schema()
  ActiveRecord.drop_schema()

  timer.Simple(0.25, function()
    ActiveRecord.generate_tables()

    print 'Done! Restarting...'

    timer.Simple(0.5, function()
      RunConsoleCommand('changelevel', game.GetMap())
    end)
  end)
end

Pipeline.register('migrations', function(id, file_name, pipe)
  if file_name:end_with('.lua') then
    ActiveRecord.Migrator:add_file(file_name)
  end
end)
