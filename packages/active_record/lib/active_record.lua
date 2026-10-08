--- ActiveRecord is Flux's object-relational mapper, modelled on the Rails library of the
-- same name. It ties classes to database tables: a model is a class that extends
-- `ActiveRecord::Base`, its table is named after the lowercase plural of the class name,
-- and every row of that table is loaded as an object of the class and written back with
-- `ActiveRecord::Base#save`.
--
-- The tables are described by migrations (`ActiveRecord::Migration`): files in the
-- schema's `db/migrate/` folder that change the database through the schema statements
-- (`create_table`, `add_column`, `add_index` and so on). Pending migrations are run when
-- the server starts or through the `flux db:*` console commands (`ActiveRecord.Tasks`),
-- and the resulting schema is dumped into `db/schema.lua`. All SQL goes through a database
-- adapter (`ActiveRecord::Adapters::Abstract`) for SQLite, MySQL or PostgreSQL, picked by
-- the settings of the current environment in `config/database.yml`.
--
-- The functions on the `ActiveRecord` table itself connect to the database, bring the
-- library up and keep its bookkeeping: the columns of every table are mirrored in
-- `ActiveRecord.schema` and in the 'ar_schema' table, and the indexes, foreign keys and
-- primary keys in `ActiveRecord.metadata` and in the 'ar_metadata' key-value table.
-- `ActiveRecord.ready` is set once the stored schema has been read back, and the
-- `ActiveRecordReady` hook is run when startup is complete. The library only exists on
-- the server; the client gets a stub of `ActiveRecord::Base`.
-- @module [ActiveRecord]

-- Store for later use.
local PACKAGE = PACKAGE

ActiveRecord.schema       = ActiveRecord.schema               or {}
ActiveRecord.db_settings  = DatabaseSettings[ENV['FLUX_ENV']] or DatabaseSettings['development'] or {}
ActiveRecord.adapter_name = ActiveRecord.db_settings.adapter  or 'sqlite'
ActiveRecord.metadata     = ActiveRecord.metadata             or {
  indexes     = {},
  references  = {},
  prim_keys   = {}
}

include 'generators/generator.lua'
include 'database/database.lua'
include 'database/query.lua'
include 'adapters/abstract.lua'
include 'database/queue.lua'
include 'schema_statements.lua'
include 'migrator/migrator.lua'
include 'model.lua'
include 'validator.lua'
include 'base.lua'
include 'helpers.lua'
include 'commandline.lua'
include 'dumper.lua'

-- Order in which the columns of a table were added; continues from the ids stored in
-- the 'ar_schema' table.
local next_column_id = 1

local function parse_definition(definition)
  definition = tostring(definition or '')

  local null = nil
  local default = definition:match(' DEFAULT (.+)$')

  if definition:find(' NOT NULL') then
    null = false
  elseif default == 'NULL' then
    null = true
    default = nil
  end

  return null, default
end

--- Registers a column in the in-memory schema, inserting a row into the 'ar_schema'
-- table if the column is new. Throws an error if ActiveRecord is not ready yet.
-- @param table_name [String database table the column belongs to]
-- @param column_name [String]
-- @param type [String abstract column type, e.g. 'string', 'integer' or 'datetime']
-- @param definition=nil [String SQL definition of the column, including its NOT NULL
--   and DEFAULT clauses; the adapter's definition of the type if not given]
-- @param options=nil [Map column options: null (Boolean) and default]
function ActiveRecord.add_to_schema(table_name, column_name, type, definition, options)
  if !ActiveRecord.ready then
    error('Attempt to edit the schema too early!')
  end

  definition = definition or ActiveRecord.adapter.types[type] or ''
  options = options or {}

  local t = ActiveRecord.schema[table_name] or {}
  local column = { type = type, null = options.null, default = options.default }

  if t[column_name] then
    column.id = t[column_name].id

    local query = ActiveRecord.Database:update('ar_schema')
      query:where('table_name', table_name)
      query:where('column_name', column_name)
      query:update('abstract_type', type)
      query:update('definition', definition)
    query:execute()
  else
    column.id = next_column_id
    next_column_id = next_column_id + 1

    local query = ActiveRecord.Database:insert('ar_schema')
      query:insert('table_name', table_name)
      query:insert('column_name', column_name)
      query:insert('abstract_type', type)
      query:insert('definition', definition)
    query:execute()
  end

  t[column_name] = column

  ActiveRecord.schema[table_name] = t
end

--- Forgets a column of the in-memory schema and deletes its row from 'ar_schema'.
-- @param table_name [String]
-- @param column_name [String]
function ActiveRecord.remove_from_schema(table_name, column_name)
  local t = ActiveRecord.schema[table_name]

  if t then
    t[column_name] = nil
  end

  if !ActiveRecord.ready then return end

  local query = ActiveRecord.Database:delete('ar_schema')
    query:where('table_name', table_name)
    query:where('column_name', column_name)
  query:execute()
end

--- Renames a column in the in-memory schema and in 'ar_schema'.
-- @param table_name [String]
-- @param column_name [String]
-- @param new_name [String]
function ActiveRecord.rename_in_schema(table_name, column_name, new_name)
  local t = ActiveRecord.schema[table_name]

  if t and t[column_name] then
    t[new_name] = t[column_name]
    t[column_name] = nil
  end

  if !ActiveRecord.ready then return end

  local query = ActiveRecord.Database:update('ar_schema')
    query:where('table_name', table_name)
    query:where('column_name', column_name)
    query:update('column_name', new_name)
  query:execute()
end

--- Forgets a table of the in-memory schema and deletes its rows from 'ar_schema'.
-- @param table_name [String]
function ActiveRecord.drop_from_schema(table_name)
  ActiveRecord.schema[table_name] = nil

  if !ActiveRecord.ready then return end

  local query = ActiveRecord.Database:delete('ar_schema')
    query:where('table_name', table_name)
  query:execute()
end

--- Renames a table in the in-memory schema and in 'ar_schema'.
-- @param table_name [String]
-- @param new_name [String]
function ActiveRecord.rename_table_in_schema(table_name, new_name)
  ActiveRecord.schema[new_name] = ActiveRecord.schema[table_name]
  ActiveRecord.schema[table_name] = nil

  if !ActiveRecord.ready then return end

  local query = ActiveRecord.Database:update('ar_schema')
    query:where('table_name', table_name)
    query:update('table_name', new_name)
  query:execute()
end

local metadata_kinds = {
  index       = 'indexes',
  foreign_key = 'references',
  primary_key = 'prim_keys'
}

--- Records an index, foreign key or primary key in the metadata, both in memory and in
-- the 'ar_metadata' table (under the key '<kind>:<name>').
-- @param kind [String 'index', 'foreign_key' or 'primary_key']
-- @param name [String name of the index or constraint]
-- @param entry [Map its description, as written by the schema statements]
function ActiveRecord.store_metadata(kind, name, entry)
  ActiveRecord.metadata[metadata_kinds[kind]][name] = entry

  if ActiveRecord.ready then
    ActiveRecord.set_meta_key(kind..':'..name, util.TableToJSON(entry))
  end
end

--- Removes an index, foreign key or primary key from the metadata.
-- @param kind [String 'index', 'foreign_key' or 'primary_key']
-- @param name [String]
function ActiveRecord.forget_metadata(kind, name)
  ActiveRecord.metadata[metadata_kinds[kind]][name] = nil

  if ActiveRecord.ready then
    ActiveRecord.delete_meta_key(kind..':'..name)
  end
end

--- Loads the metadata (indexes, foreign keys and primary keys) from the 'ar_metadata'
-- table into ActiveRecord.metadata.
-- @warning [Internal]
function ActiveRecord.restore_metadata()
  ActiveRecord.metadata = { indexes = {}, references = {}, prim_keys = {} }

  local query = ActiveRecord.Database:select('ar_metadata')
    query:callback(function(result, query_str, time)
      print_query('Metadata Restore ('..time..'s)', query_str)

      if !istable(result) then return end

      for k, v in ipairs(result) do
        local kind, name = tostring(v.key):match('^(%a+_?%a*):(.+)$')

        if kind and metadata_kinds[kind] then
          local entry = util.JSONToTable(tostring(v.value))

          if istable(entry) then
            ActiveRecord.metadata[metadata_kinds[kind]][name] = entry
          end
        end
      end
    end)
  query:execute()
end

--- Loads the stored schema from the 'ar_schema' table. Once loaded, marks ActiveRecord
-- as ready, populates the models and creates the tables queued by #define_model.
-- @warning [Internal]
function ActiveRecord.restore_schema()
  ActiveRecord.schema = {}

  local query = ActiveRecord.Database:select('ar_schema')
    query:callback(function(result, query, time)
      print_query('Schema Restore ('..time..'s)', query)

      if istable(result) then
        for k, v in ipairs(result) do
          local t = ActiveRecord.schema[v.table_name] or {}
          local null, default = parse_definition(v.definition)

          v.id = tonumber(v.id) or 0
          t[v.column_name] = { id = v.id, type = v.abstract_type, null = null, default = default }
          ActiveRecord.schema[v.table_name] = t

          next_column_id = math.max(next_column_id, v.id + 1)
        end
      end

      ActiveRecord.restore_metadata()

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

--- Deletes a key from the 'ar_metadata' key-value table.
-- @param key [String]
function ActiveRecord.delete_meta_key(key)
  local query = ActiveRecord.Database:delete('ar_metadata')
    query:where('key', key)
    query:callback(function(r, query_str, time)
      print_query('Meta Delete ('..time..'s)', query_str)
    end)
  query:execute()
end

--- Defines the database table of a model. Meant to be used in migrations.
-- The 'id' primary key and the 'created_at' / 'updated_at' columns are added
-- automatically. The table is created right away, or queued until the schema is
-- restored if ActiveRecord is not ready yet. Reverted with drop_table.
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
--   time, date, binary, boolean and json, as well as timestamps and references]
function ActiveRecord.define_model(name, callback)
  if ActiveRecord.ready then
    ActiveRecord.ddl('define_model', name, callback)
  else
    ActiveRecord.Queue:add(name, function(t)
      callback(t)
      t:timestamps()
    end)
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
-- restores the schema, brings the database up to date (see ActiveRecord.Tasks.prepare)
-- and fires the 'ActiveRecordReady' hook.
-- @warning [Internal]
function ActiveRecord.on_connected()
  Flux.dev_print 'ActiveRecord - Connected to the database!'

  ActiveRecord.generate_tables()
  ActiveRecord.restore_schema()

  local class_name = ActiveRecord.adapter.class_name:lower()
  local adapter = ActiveRecord.get_meta_key('adapter', class_name)

  -- The internal tables were written by another database adapter: start over.
  if adapter != class_name then
    ActiveRecord.drop_schema(true)
    ActiveRecord.generate_tables()
    ActiveRecord.restore_schema()

    adapter = class_name
  end

  ActiveRecord.set_meta_key('adapter', adapter)

  ActiveRecord.migration_context = ActiveRecord.MigrationContext.new()

  local success, exception = pcall(ActiveRecord.Tasks.prepare)

  if !success then
    ErrorNoHalt('ActiveRecord - Unable to bring the database up to date!\n')
    long_error(tostring(exception)..'\n')
  end

  --- Called on the server once ActiveRecord has finished starting up: the database is
  -- connected, the stored schema is restored, the models know their columns and the
  -- pending migrations have been run. It is called even if bringing the database up to
  -- date failed. This is the place to load data that has to be in memory from the start.
  -- The adapter is in sync mode during the call, so queries made by a handler finish
  -- before it returns. `DatabaseConnected` is run right after it.
  -- @realm [server]
  hook.Run('ActiveRecordReady')
end

--- Drops the internal 'ar_schema', 'ar_metadata' and 'ar_schema_migrations' tables and,
-- unless told otherwise, every table known to the schema. This destroys the stored data.
-- @param meta_only=false [Boolean only drop the internal tables]
function ActiveRecord.drop_schema(meta_only)
  if !meta_only then
    for k, v in ipairs(table.GetKeys(ActiveRecord.schema)) do
      ActiveRecord.SchemaStatements.drop_table(v, { if_exists = true })
    end
  end

  ActiveRecord.SchemaStatements.drop_table('ar_schema', { if_exists = true })
  ActiveRecord.SchemaStatements.drop_table('ar_metadata', { if_exists = true })
  ActiveRecord.SchemaMigration:drop_table()

  ActiveRecord.schema = {}
  ActiveRecord.metadata = { indexes = {}, references = {}, prim_keys = {} }
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
    ActiveRecord.MigrationContext.add_source(file_name)
  end
end)
