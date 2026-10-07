--- The database tasks behind the `flux db:*` console commands: migrating, rolling back,
-- inspecting the migration status and dumping or loading the schema file.
ActiveRecord.Tasks = ActiveRecord.Tasks or {}

local Tasks = ActiveRecord.Tasks

--- Whether the schema file is regenerated after migrations have been run.
-- @return [Boolean]
ActiveRecord.dump_schema_after_migration = true

--- Returns the migration context of the active schema, creating it if needed.
-- @return [ActiveRecord::MigrationContext]
function Tasks.context()
  ActiveRecord.migration_context = ActiveRecord.migration_context or ActiveRecord.MigrationContext.new()
  return ActiveRecord.migration_context
end

--- Returns the path of the schema file, relative to the game folder.
-- @return [String e.g. 'gamemodes/reborn/db/schema.lua']
function Tasks.schema_path()
  return 'gamemodes/'..Flux.get_schema_folder()..'/db/schema.lua'
end

--- Refreshes the models and regenerates the schema file once migrations have run.
-- @param executed [List<ActiveRecord::MigrationProxy> migrations that were run]
-- @return [List<ActiveRecord::MigrationProxy> the same list]
function Tasks.after_migration(executed)
  ActiveRecord.Model:populate()

  if #executed > 0 and ActiveRecord.dump_schema_after_migration then
    Tasks.schema_dump()
  end

  return executed
end

--- Runs the pending migrations, or migrates to a version (`flux db:migrate VERSION=x`).
-- @param version=nil [Number/String]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function Tasks.migrate(version)
  local executed = Tasks.context():migrate(version)

  if #executed == 0 then
    print('ActiveRecord - The database is up to date (version '..Tasks.context():current_version()..').')
  end

  return Tasks.after_migration(executed)
end

--- Runs a single migration (`flux db:migrate:up VERSION=x`).
-- @param version [Number/String]
-- @return [List<ActiveRecord::MigrationProxy>]
function Tasks.migrate_up(version)
  if !tonumber(version) then
    error('VERSION is required', 0)
  end

  return Tasks.after_migration(Tasks.context():run('up', version))
end

--- Reverts a single migration (`flux db:migrate:down VERSION=x`).
-- @param version [Number/String]
-- @return [List<ActiveRecord::MigrationProxy>]
function Tasks.migrate_down(version)
  if !tonumber(version) then
    error('VERSION is required', 0)
  end

  return Tasks.after_migration(Tasks.context():run('down', version))
end

--- Reverts the newest migrations (`flux db:rollback STEP=n`).
-- @param steps=1 [Number]
-- @return [List<ActiveRecord::MigrationProxy>]
function Tasks.rollback(steps)
  return Tasks.after_migration(Tasks.context():rollback(tonumber(steps) or 1))
end

--- Runs the next pending migrations (`flux db:forward STEP=n`).
-- @param steps=1 [Number]
-- @return [List<ActiveRecord::MigrationProxy>]
function Tasks.forward(steps)
  return Tasks.after_migration(Tasks.context():forward(tonumber(steps) or 1))
end

--- Reverts and re-runs migrations (`flux db:migrate:redo STEP=n` or `VERSION=x`).
-- @param steps=1 [Number]
-- @param version=nil [Number/String a single migration to redo]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run again]
function Tasks.redo(steps, version)
  if tonumber(version) then
    Tasks.context():run('down', version)
    return Tasks.after_migration(Tasks.context():run('up', version))
  end

  Tasks.context():rollback(tonumber(steps) or 1)

  return Tasks.after_migration(Tasks.context():migrate())
end

--- Prints the status of every migration (`flux db:migrate:status`).
function Tasks.migrate_status()
  print('\ndatabase: '..tostring(ActiveRecord.db_settings.database or ActiveRecord.adapter_name)..'\n')
  print(' Status   Migration ID    Migration Name')
  print('--------------------------------------------------')

  for k, v in ipairs(Tasks.context():migrations_status()) do
    print(string.format('%8s  %-14s  %s', v.status, v.version, v.name))
  end

  print('')
end

--- Prints the current schema version (`flux db:version`).
function Tasks.version()
  print('Current version: '..Tasks.context():current_version())
end

--- Writes the current schema into the schema file (`flux db:schema:dump`).
-- @return [String path of the file]
function Tasks.schema_dump()
  local path = Tasks.schema_path()

  File.write(path, ActiveRecord.dump_schema(Tasks.context():current_version()))
  Flux.dev_print('ActiveRecord - Dumped the schema into '..path)

  return path
end

--- Checks whether the schema file holds a 'Structure' object (the one-argument form of
-- ActiveRecord.Schema:define). Such a file cannot be loaded.
-- @return [Boolean]
function Tasks.structure_schema_file()
  local contents = File.read(Tasks.schema_path())
  return isstring(contents) and contents:find('ActiveRecord%.Schema:define%(%s*%d') != nil
end

--- Loads the schema file, which creates the tables it describes and records its version
-- and every older migration as run (`flux db:schema:load`).
function Tasks.schema_load()
  local path = Tasks.schema_path()

  if !file.Exists(path, 'GAME') then
    error('ActiveRecord - the schema file '..path..' does not exist. Run the migrations to generate it.', 0)
  end

  if Tasks.structure_schema_file() then
    error(
      'ActiveRecord - the schema file '..path..' holds a \'Structure\' object and cannot be loaded. '..
      'Run the migrations to regenerate it.',
      0
    )
  end

  print('ActiveRecord - Loading the schema from '..path..'...')

  include((path:gsub('^gamemodes/', '')))
end

--- Records the migrations as run for a database whose newest migration version is stored
-- under the 'version' key of the 'ar_metadata' table, with nothing in the
-- 'ar_schema_migrations' table. Every migration file up to that version is considered
-- run, the key is deleted, and the indexes and foreign keys of a schema file that holds
-- a 'Structure' object are imported into the metadata.
function Tasks.import_metadata_version()
  if #Tasks.context():get_all_versions() > 0 then return end

  local metadata_version = tonumber(ActiveRecord.get_meta_key('version', 0)) or 0

  if metadata_version <= 0 then return end

  print('ActiveRecord - Recording the migrations up to version '..metadata_version..' as run...')

  Tasks.context():assume_migrated_upto_version(metadata_version)
  ActiveRecord.delete_meta_key('version')

  if table.Count(ActiveRecord.metadata.indexes) == 0 and Tasks.structure_schema_file() then
    local structure = include((Tasks.schema_path():gsub('^gamemodes/', '')))

    if istable(structure) and istable(structure.metadata) then
      Tasks.import_structure_metadata(structure.metadata)
    end
  end
end

--- Imports the metadata (indexes, references and primary keys) of a schema file that
-- holds a 'Structure' object.
-- @param metadata [Map]
function Tasks.import_structure_metadata(metadata)
  for name, args in pairs(metadata.indexes or {}) do
    if istable(args) and isstring(args[1]) and args[2] then
      ActiveRecord.store_metadata('index', name, {
        table = args[1],
        columns = istable(args[2]) and args[2] or { args[2] },
        unique = tobool(args.unique) or nil,
        length = args.length,
        using = args.using,
        where = args.where
      })
    end
  end

  for name, args in pairs(metadata.references or {}) do
    if istable(args) then
      ActiveRecord.store_metadata('foreign_key', name, {
        from_table = args.table_name or args.table,
        to_table = args.foreign_table,
        column = args.key,
        primary_key = args.foreign_key or 'id',
        on_delete = tobool(args.cascade) and 'cascade' or nil
      })
    end
  end

  for name, args in pairs(metadata.prim_keys or {}) do
    if istable(args) and args[1] then
      ActiveRecord.store_metadata('primary_key', name, { table = args[1], column = args[2] })
    end
  end
end

--- Brings the database up to date when the server starts: installs the migrations of
-- the packages and plugins, loads the schema file into a fresh database and runs the
-- pending migrations.
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function Tasks.prepare()
  local context = Tasks.context()

  Tasks.import_metadata_version()
  context:install_migrations()

  local fresh = #context:get_all_versions() == 0 and table.Count(ActiveRecord.schema) == 0

  if fresh and file.Exists(Tasks.schema_path(), 'GAME') and !Tasks.structure_schema_file() then
    Tasks.schema_load()
  end

  return Tasks.migrate()
end

local tasks = {
  ['migrate']         = function(env) return Tasks.migrate(env.VERSION) end,
  ['migrate:up']      = function(env) return Tasks.migrate_up(env.VERSION) end,
  ['migrate:down']    = function(env) return Tasks.migrate_down(env.VERSION) end,
  ['migrate:redo']    = function(env) return Tasks.redo(env.STEP, env.VERSION) end,
  ['migrate:status']  = function(env) return Tasks.migrate_status() end,
  ['rollback']        = function(env) return Tasks.rollback(env.STEP) end,
  ['forward']         = function(env) return Tasks.forward(env.STEP) end,
  ['version']         = function(env) return Tasks.version() end,
  ['schema:dump']     = function(env) return Tasks.schema_dump() end,
  ['schema:load']     = function(env) return Tasks.schema_load() end,
  ['create']          = function(env) return ActiveRecord.Database:setup(ActiveRecord.db_settings) end,
  ['drop']            = function(env) return ActiveRecord.Database:drop_database(ActiveRecord.db_settings) end
}

-- Tasks that need a connected database.
local needs_connection = {
  ['create'] = false,
  ['drop'] = false
}

--- Returns the names of the console tasks.
-- @return [List<String> sorted]
function Tasks.names()
  local names = table.GetKeys(tasks)
  table.sort(names)
  return names
end

--- Runs a task by its console name, e.g. 'migrate:status', with the adapter in sync
-- mode. Errors are printed instead of raised.
-- @param name [String]
-- @param env=nil [Map KEY=VALUE arguments of the command, e.g. { VERSION = '2019...' }]
-- @return [Boolean whether the task ran without an error]
function Tasks.run(name, env)
  local task = tasks[name]

  if !task then
    print('Unknown task db:'..tostring(name)..'. Available tasks: db:'..table.concat(Tasks.names(), ', db:'))
    return false
  end

  if needs_connection[name] != false and !ActiveRecord.ready then
    print('ActiveRecord is not connected to the database yet!')
    return false
  end

  local adapter = ActiveRecord.adapter

  adapter:sync(true)

  local success, exception = pcall(task, env or {})

  adapter:sync(false)

  if !success then
    ErrorNoHalt('ActiveRecord - db:'..name..' failed!\n')
    long_error(tostring(exception)..'\n')
  end

  return success
end
