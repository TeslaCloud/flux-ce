--- ActiveRecord is Flux's object-relational mapper. It ties classes to database tables: a
-- model is a class that extends `ActiveRecord::Base`, its table is named after the
-- lowercase plural of the class name, and every row of that table is loaded as an object
-- of the class and written back with `ActiveRecord::Base#save`. Models are related with
-- `has_many`, `has_one` and `belongs_to`; a query loads the rows of its own model only, and
-- the related objects are loaded when the query asks for them with
-- `ActiveRecord::Base#preload`.
--
-- The tables are described by migrations (`ActiveRecord::Migration`): files in the
-- schema's `db/migrate/` folder that change the database through the schema statements
-- (`create_table`, `add_column`, `add_index` and so on). Pending migrations are run when
-- the server starts, through the `flux db:*` console commands, or from the shell without the
-- server through fpkg's tasks (`fpkg db:migrate`, see the package's `taskspec.lua`), all of
-- them `ActiveRecord.Tasks`, and the resulting schema is dumped into `db/schema.lua`. All SQL
-- goes through a database adapter (`ActiveRecord::Adapters::Abstract`) for SQLite, MySQL or
-- PostgreSQL, picked by the settings of the current environment in `config/database.yml`.
--
-- The functions on the `ActiveRecord` table itself connect to the database, bring the
-- library up and keep its bookkeeping: the columns of every table are mirrored in
-- `ActiveRecord.schema` and in the 'ar_schema' table, and the indexes, foreign keys and
-- primary keys in `ActiveRecord.metadata` and in the 'ar_metadata' key-value table.
-- `ActiveRecord.ready` is set once the stored schema has been read back, and the
-- `ActiveRecordReady` hook is run when startup is complete. The library only exists on
-- the server; the client gets a stub of `ActiveRecord::Base`.
-- @module [ActiveRecord]

local PACKAGE = PACKAGE

ActiveRecord.schema       = ActiveRecord.schema or {}
ActiveRecord.db_section   = DatabaseSettings[ENV['FLUX_ENV']] and ENV['FLUX_ENV'] or 'development'
ActiveRecord.db_settings  = DatabaseSettings[ActiveRecord.db_section] or {}
ActiveRecord.adapter_name = ActiveRecord.db_settings.adapter or 'sqlite'
ActiveRecord.metadata     = ActiveRecord.metadata or {
  indexes     = {},
  references  = {},
  prim_keys   = {}
}

include 'inflector/inflector.lua'
include 'inflector/inflections.lua'
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

--- Order in which the columns of a table were added; continues from the ids stored in
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
    next_column_id += 1

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
    query:callback(function(result, query_str, time, bindings)
      print_query('Metadata Restore ('..time..'s)', query_str, bindings)

      if !istable(result) then return end

      for _, row in ipairs(result) do
        local kind, name = tostring(row.key):match('^(%a+_?%a*):(.+)$')

        if kind and metadata_kinds[kind] then
          local entry = util.JSONToTable(tostring(row.value))

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
    query:callback(function(result, query_str, time, bindings)
      print_query('Schema Restore ('..time..'s)', query_str, bindings)

      if istable(result) then
        for _, row in ipairs(result) do
          local t = ActiveRecord.schema[row.table_name] or {}
          local null, default = parse_definition(row.definition)

          row.id = tonumber(row.id) or 0
          t[row.column_name] = { id = row.id, type = row.abstract_type, null = null, default = default }
          ActiveRecord.schema[row.table_name] = t

          next_column_id = math.max(next_column_id, row.id + 1)
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
    query:callback(function(res, query_str, time, bindings)
      print_query('Meta Get ('..time..'s)', query_str, bindings)

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
          q:callback(function(_r, query_str, time, bindings)
            print_query('Meta Update ('..time..'s)', query_str, bindings)
          end)
        q:execute()
      else
        local q = ActiveRecord.Database:insert('ar_metadata')
          q:insert('key', key)
          q:insert('value', value)
          q:callback(function(_r, query_str, time, bindings)
            print_query('Meta Insert ('..time..'s)', query_str, bindings)
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
    query:callback(function(_r, query_str, time, bindings)
      print_query('Meta Delete ('..time..'s)', query_str, bindings)
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

--- Aliases for common adapter names.
local adapter_aliases = {
  ['postgresql']  = 'pg',
  ['postgres']    = 'pg',
  ['sqlite3']     = 'sqlite',
  ['mysql']       = 'mysqloo',
  ['mariadb']     = 'mysqloo'
}

--- Lists the adapter names that the database settings may give: the adapters in
-- `lib/adapters/` and their aliases.
-- @return [List<String> sorted]
local function valid_adapter_names()
  local names = {}

  for _, file_name in ipairs(file.Find(PACKAGE.__path__..'lib/adapters/*.lua', 'LUA')) do
    if file_name != 'abstract.lua' then
      names[#names + 1] = file_name:gsub('%.lua$', '')
    end
  end

  for alias in pairs(adapter_aliases) do
    names[#names + 1] = alias
  end

  table.sort(names)

  return names
end

--- Finds the adapter class that database settings name: 'sqlite' if they name none, with the
-- aliases 'postgresql', 'postgres', 'sqlite3', 'mysql' and 'mariadb' resolved (the adapter
-- field of the settings is rewritten in that case). Loads the file of the adapter and stores
-- the resolved name in ActiveRecord.adapter_name.
-- @param config [Map database settings]
-- @return [Class the adapter class, nil for an unknown name; String the reason, which names
--   the valid adapters]
local function find_adapter(config)
  local adapter = isstring(config.adapter) and config.adapter:lower() or 'sqlite'

  if adapter_aliases[adapter] then
    adapter         = adapter_aliases[adapter]
    config.adapter  = adapter
  end

  ActiveRecord.adapter_name = adapter

  local path = PACKAGE.__path__..'lib/adapters/'..adapter..'.lua'

  if adapter != 'abstract' and file.Exists(path, 'LUA') then
    include(path)
  end

  local adapter_class = adapter != 'abstract' and ActiveRecord.Adapters[adapter:capitalize()]

  if !adapter_class then
    return nil, 'Unknown database adapter \''..adapter..'\' in the \''..ActiveRecord.db_section..'\' section of '
      ..Flux.find_config('database.yml')..'! Valid adapters: '..table.concat(valid_adapter_names(), ', ')
  end

  return adapter_class
end

--- Loads the database adapter named in the config and connects it to the database.
-- Uses 'sqlite' if no adapter is named, and resolves the aliases 'postgresql', 'postgres',
-- 'sqlite3', 'mysql' and 'mariadb' (the config's adapter field is rewritten in that case).
-- The resolved name is stored in ActiveRecord.adapter_name. An unknown name is reported
-- along with the valid ones, and no connection is made. A connection that fails is tried
-- again, see ActiveRecord.reconnect. Once connected, ActiveRecord starts up, see
-- ActiveRecord.on_connected.
-- ```
-- ActiveRecord.establish_connection {
--   adapter = 'mysqloo', host = '127.0.0.1', port = 3306,
--   user = 'username', password = 'password', database = 'flux_dev'
-- }
-- ```
-- @param config [Map database settings as found in config/database.yml: adapter, host,
--   port, user, password, database, encoding, socket and flags]
function ActiveRecord.establish_connection(config)
  local adapter_class, reason = find_adapter(config)

  if !adapter_class then
    ErrorNoHalt('ActiveRecord - '..reason..'\n')

    return
  end

  ActiveRecord.connection_settings = config
  ActiveRecord.connection_attempts = 0
  ActiveRecord.adapter = adapter_class.new()
  ActiveRecord.adapter:connect(config, ActiveRecord.Adapters.Abstract.on_connected)
end

--- Creates the adapter that database settings name and stores it in ActiveRecord.adapter,
-- without connecting it, as the tasks that need no connection (`db:create`, `db:drop`) want
-- it. Raises an error for an unknown adapter, and one with the reason when the binary module
-- of the adapter cannot be opened.
-- @param config [Map database settings, see ActiveRecord.establish_connection]
-- @return [ActiveRecord::Adapters::Abstract the adapter]
function ActiveRecord.create_adapter(config)
  local adapter_class, reason = find_adapter(config)

  if !adapter_class then
    error('ActiveRecord - '..reason, 0)
  end

  local binary_module = adapter_class.binary_module

  if binary_module then
    local loaded, exception = pcall(require, binary_module)

    if !loaded then
      error('ActiveRecord - The '..binary_module..' module of the '..ActiveRecord.adapter_name..' adapter cannot be '
        ..'opened: '..tostring(exception):match('^[^\n]*'), 0)
    end
  end

  ActiveRecord.connection_settings = config
  ActiveRecord.adapter = adapter_class.new()

  return ActiveRecord.adapter
end

--- Connects to the database for fpkg's tasks: creates the adapter (see
-- ActiveRecord.create_adapter), connects it and readies the database without changing the
-- tables of the application, which creates the internal tables, restores the schema and
-- installs the migrations of the packages and plugins (see ActiveRecord.open_database and
-- ActiveRecord.Tasks.install). Nothing is migrated and no hook is run. Raises an error that says
-- why when the database cannot be used.
-- @param config [Map database settings, see ActiveRecord.establish_connection]
function ActiveRecord.connect(config)
  local adapter = ActiveRecord.create_adapter(config)
  local done, success, exception = false, false, nil

  adapter:connect(config, function(connected)
    connected._connected = true
    connected:sync(true)

    success, exception = pcall(function()
      local opened, reason = ActiveRecord.open_database()

      if !opened then
        error('ActiveRecord - '..reason, 0)
      end

      ActiveRecord.Tasks.install()
    end)

    connected:sync(false)
    done = true
  end)

  if !adapter:wait_until(|| -> done, 10) then
    error('ActiveRecord - Unable to connect to the database through the '..ActiveRecord.adapter_name
      ..' adapter, see the error above', 0)
  end

  if !success then
    error(exception, 0)
  end
end

--- Connects the adapter again after its connection has failed while ActiveRecord is
-- starting up, with the settings that ActiveRecord.establish_connection was given. The
-- attempts are spaced 5, 10, 20 and 40 seconds apart and then every 60 seconds, until one
-- of them succeeds; each one is announced in the console.
-- @warning [Internal]
function ActiveRecord.reconnect()
  local settings = ActiveRecord.connection_settings

  if ActiveRecord.ready or !settings then return end

  local attempt = (ActiveRecord.connection_attempts or 0) + 1
  local delay = math.min(5 * 2 ^ (attempt - 1), 60)

  ActiveRecord.connection_attempts = attempt

  print('ActiveRecord - Connecting to the database again in '..delay..' seconds (attempt '..attempt..')...')

  timer.Create('ActiveRecord#reconnect', delay, 1, function()
    if ActiveRecord.ready then return end

    print('ActiveRecord - Connecting to the database (attempt '..attempt..')...')

    ActiveRecord.adapter:connect(settings, ActiveRecord.Adapters.Abstract.on_connected)
  end)
end

--- Describes the database that the adapter is connected to, for the console.
-- @param settings [Map database settings]
-- @return [String]
local function describe_database(settings)
  local adapter = ActiveRecord.adapter

  if adapter:is_sqlite() then
    return 'the SQLite database of the server (sv.db)'
  end

  local port = settings.port or adapter.default_port

  return 'database \''..tostring(settings.database)..'\' on '..tostring(settings.host or '127.0.0.1')
    ..(port and ':'..port or '')
end

--- Readies the database once the adapter is connected, without changing the tables of the
-- application: prints which database it is connected to and where the settings come from,
-- creates the internal tables, restores the schema and checks that the tables were created
-- through the adapter that is configured. A database whose tables were created through another
-- adapter is left alone and ActiveRecord is not marked as ready. The server goes on with
-- ActiveRecord.on_connected, fpkg's tasks with ActiveRecord.connect.
-- @warning [Internal]
-- @return [Boolean whether the database can be used, String the reason when it cannot]
function ActiveRecord.open_database()
  print('ActiveRecord - Connected to '..describe_database(ActiveRecord.connection_settings or ActiveRecord.db_settings)
    ..' through the '..ActiveRecord.adapter_name..' adapter, as set in the \''..ActiveRecord.db_section
    ..'\' section of '..Flux.find_config('database.yml'))

  ActiveRecord.generate_tables()
  ActiveRecord.restore_schema()

  local class_name = ActiveRecord.adapter.class_name:lower()
  local adapter = ActiveRecord.get_meta_key('adapter', class_name)

  if adapter != class_name then
    ActiveRecord.ready = false

    return false, 'The tables of this database were created through the \''..tostring(adapter)
      ..'\' adapter, but the \''..class_name..'\' adapter is configured. Nothing has been changed and no '
      ..'migration has been run. If it is the same database, delete the \'adapter\' row of the ar_metadata '
      ..'table; otherwise point the settings at the right database.'
  end

  ActiveRecord.set_meta_key('adapter', adapter)

  ActiveRecord.migration_context = ActiveRecord.MigrationContext.new()

  return true
end

--- Bootstraps ActiveRecord on the server once the adapter is connected: readies the database
-- (see ActiveRecord.open_database), installs the migrations of the packages and plugins (see
-- ActiveRecord.Tasks.install), brings the database up to date (see ActiveRecord.Tasks.prepare)
-- and fires the 'ActiveRecordReady' hook. A database that cannot be used is reported and left
-- alone: ActiveRecord is not marked as ready, nothing is migrated and the hook is not run.
-- @warning [Internal]
-- @return [Boolean whether ActiveRecord has started up]
function ActiveRecord.on_connected()
  timer.Remove('ActiveRecord#reconnect')

  ActiveRecord.connection_attempts = 0

  local opened, reason = ActiveRecord.open_database()

  if !opened then
    ErrorNoHalt('ActiveRecord - '..reason..'\n')

    return false
  end

  local success, exception = pcall(ActiveRecord.Tasks.install)

  if success then
    success, exception = pcall(ActiveRecord.Tasks.prepare)
  end

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

  return true
end

--- Drops the internal 'ar_schema', 'ar_metadata' and 'ar_schema_migrations' tables and,
-- unless told otherwise, every table known to the schema. This destroys the stored data.
-- The tables are dropped while foreign keys are not enforced (SQLite, MySQL) or together
-- with the foreign keys that refer to them (PostgreSQL), so that their order does not
-- matter. ActiveRecord is not ready afterward. A table that cannot be dropped raises
-- an error while the adapter raises errors (see ActiveRecord::Adapters::Abstract#raise_errors)
-- and stays in the schema.
-- @param meta_only=false [Boolean only drop the internal tables]
function ActiveRecord.drop_schema(meta_only)
  local adapter = ActiveRecord.adapter

  if !meta_only then
    local foreign_keys = adapter:disable_foreign_keys()
    local mysql = adapter:is_mysql()

    if mysql then
      adapter:raw_query('SET FOREIGN_KEY_CHECKS = 0;')
    end

    local success, exception = pcall(function()
      for _, table_name in ipairs(table.GetKeys(ActiveRecord.schema)) do
        ActiveRecord.SchemaStatements.drop_table(table_name, { if_exists = true, cascade = true })
      end
    end)

    if mysql then
      adapter:raw_query('SET FOREIGN_KEY_CHECKS = 1;')
    end

    if foreign_keys then
      adapter:enable_foreign_keys()
    end

    if !success then
      error(exception, 0)
    end
  end

  ActiveRecord.ready = false

  ActiveRecord.SchemaStatements.drop_table('ar_schema', { if_exists = true })
  ActiveRecord.SchemaStatements.drop_table('ar_metadata', { if_exists = true })
  ActiveRecord.SchemaMigration:drop_table()

  ActiveRecord.schema = {}
  ActiveRecord.metadata = { indexes = {}, references = {}, prim_keys = {} }
end

--- Drops all tables, recreates the internal ones and then restarts the current map.
-- This destroys all data stored in the database. Everything runs in sync mode, and the
-- first statement that fails stops it: the error is printed and the map is not restarted.
function ActiveRecord.recreate_schema()
  local adapter = ActiveRecord.adapter
  local sync = adapter:is_sync()

  adapter:sync(true)
  adapter:raise_errors(true)

  local success, exception = pcall(function()
    ActiveRecord.drop_schema()
    ActiveRecord.generate_tables()
  end)

  adapter:raise_errors(false)
  adapter:sync(sync)

  if !success then
    ErrorNoHalt('ActiveRecord - Unable to recreate the database, the map is not restarted!\n')
    long_error(tostring(exception)..'\n')

    return
  end

  print 'Done! Restarting...'

  timer.Simple(0.5, function()
    RunConsoleCommand('changelevel', game.GetMap())
  end)
end

Pipeline.register('migrations', function(_id, file_name, _pipe)
  if file_name:end_with('.lua') then
    ActiveRecord.MigrationContext.add_source(file_name)
  end
end)
