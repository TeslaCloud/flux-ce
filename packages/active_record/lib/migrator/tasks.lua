--- The database tasks behind the `flux db:*` console commands and fpkg's `db:*` tasks
-- (`fpkg db:migrate`, run from the shell without the game server): migrating, rolling back,
-- inspecting the migration status, dumping or loading the schema file, and the generators
-- behind `flux generate` and `fpkg generate`. The tasks are listed once, in `task_list.lua`.
-- `Tasks.execute` runs one and raises its errors, `Tasks.run` prints them instead.
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

  for _, migration in ipairs(Tasks.context():migrations_status()) do
    print(string.format('%8s  %-14s  %s', migration.status, migration.version, migration.name))
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
        on_delete = tobool(args.cascade) ? 'cascade' : nil
      })
    end
  end

  for name, args in pairs(metadata.prim_keys or {}) do
    if istable(args) and args[1] then
      ActiveRecord.store_metadata('primary_key', name, { table = args[1], column = args[2] })
    end
  end
end

--- Records what the database has run and installs the migrations of the packages and plugins:
-- imports the version of a database that keeps it in the metadata, copies the registered
-- migrations into the schema's folder (see ActiveRecord::MigrationContext#install_migrations)
-- and warns about versions that have been run but have no file anymore. The connection does
-- this on the server and in fpkg's tasks, before anything else uses the database.
function Tasks.install()
  local context = Tasks.context()

  Tasks.import_metadata_version()
  context:install_migrations()

  local missing = context:versions_without_file()

  if #missing > 0 then
    ErrorNoHalt(
      'ActiveRecord - '..#missing..' migration(s) recorded as run have no file: '..
      table.concat(missing, ', ')..'\n'..
      'Restore the files, or check `flux db:migrate:status`.\n'
    )
  end
end

--- Brings the database up to date, as the server does once it has connected (`flux db:prepare`):
-- loads the schema file into a fresh database and runs the pending migrations.
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function Tasks.prepare()
  local fresh = #Tasks.context():get_all_versions() == 0 and table.Count(ActiveRecord.schema) == 0

  if fresh and file.Exists(Tasks.schema_path(), 'GAME') and !Tasks.structure_schema_file() then
    Tasks.schema_load()
  end

  return Tasks.migrate()
end

--- Connects to the database of the current environment for fpkg's tasks, raising an error that
-- says why when it cannot (see ActiveRecord.connect). Nothing of the application changes: the
-- connection only readies the database and installs the migrations (see Tasks.install).
function Tasks.connect()
  ActiveRecord.connect(ActiveRecord.db_settings)
end

--- The tasks, their usage and their descriptions, see `task_list.lua`.
Tasks.list = include 'task_list.lua'

local by_name = {}
local generators = {}

for _, entry in ipairs(Tasks.list.database) do
  by_name[entry.name] = entry
end

for _, entry in ipairs(Tasks.list.generators) do
  generators[entry.name] = entry
end

--- Returns the names of the database tasks.
-- @return [List<String> sorted]
function Tasks.names()
  local names = table.GetKeys(by_name)
  table.sort(names)
  return names
end

local option_checks = {
  x = value -> value:match('^%d+$') != nil,
  n = value -> value:match('^%d+$') != nil and tonumber(value) > 0
}

local option_kinds = {
  x = 'the version of a migration, the number its file name starts with (db:migrate:status lists them)',
  n = 'a number of migrations, 1 or more'
}

--- Finds a task by its name and checks the options and words it is given against its usage.
-- Raises an error for an unknown task, and one that says what to pass when the options or words
-- do not fit: an option or word the task does not take, an option it needs that is missing or
-- the value of an option that is not what the option stands for.
-- @param name [String task name without the 'db:' prefix]
-- @param env=nil [Map KEY=VALUE options]
-- @param words=nil [List<String> other words]
-- @return [Map the task, see task_list.lua]
function Tasks.check(name, env, words)
  local entry = by_name[name]

  if !entry then
    error('Unknown task db:'..tostring(name)..'. Available tasks: db:'..table.concat(Tasks.names(), ', db:'), 0)
  end

  env = env or {}
  words = words or {}

  local task_name = 'db:'..entry.name
  local accepted = {}
  local usage = entry.usage or ''

  for word in usage:gmatch('%S+') do
    local optional, key, kind = word:match('^(%[?)([%u_]+)=(%a)%]?$')

    if key then
      accepted[key] = kind

      if optional == '' and env[key] == nil then
        error(task_name..' needs '..key..'='..kind..', '..option_kinds[kind], 0)
      end
    end
  end

  local takes = usage != '' ? ' It takes '..usage..'.' : ' It takes no arguments.'

  if words[1] then
    error(task_name..' does not take \''..words[1]..'\'.'..takes, 0)
  end

  for key, value in pairs(env) do
    local kind = accepted[key]

    if !kind then
      error(task_name..' does not take '..key..'.'..takes, 0)
    elseif !option_checks[kind](tostring(value)) then
      error(key..' of '..task_name..' has to be '..option_kinds[kind]..', not \''..tostring(value)..'\'', 0)
    end
  end

  return entry
end

--- Runs a task by its name, e.g. 'migrate:status', with the adapter in sync mode, and raises an
-- error when it fails. It validates the task and its arguments with Tasks.check first, since
-- the console calls it directly, then raises when the task needs a connection while there is
-- none, and for an error of the task itself. A task that runs without a connection creates the
-- adapter of the database settings first when there is none.
-- @param name [String task name without the 'db:' prefix]
-- @param env=nil [Map KEY=VALUE options, e.g. { VERSION = '2019...' }]
-- @param words=nil [List<String> other words given to the task]
function Tasks.execute(name, env, words)
  env = env or {}

  local entry = Tasks.check(name, env, words)

  if entry.connection != false and !ActiveRecord.ready then
    error('ActiveRecord is not connected to the database!', 0)
  end

  if !ActiveRecord.adapter then
    ActiveRecord.create_adapter(ActiveRecord.db_settings)
  end

  local adapter = ActiveRecord.adapter

  adapter:sync(true)

  local success, exception = pcall(entry.run, env)

  adapter:sync(false)

  if !success then
    error(exception, 0)
  end
end

--- Runs a task by its console name, e.g. 'migrate:status', and prints the error instead of
-- raising it, see Tasks.execute.
-- @param name [String task name without the 'db:' prefix]
-- @param env=nil [Map KEY=VALUE options of the command, e.g. { VERSION = '2019...' }]
-- @param words=nil [List<String> other words of the command]
-- @return [Boolean whether the task ran without an error]
function Tasks.run(name, env, words)
  local success, exception = pcall(Tasks.execute, name, env, words)

  if !success then
    ErrorNoHalt('ActiveRecord - db:'..tostring(name)..' failed!\n')
    long_error(tostring(exception)..'\n')
  end

  return success
end

--- Runs a generator (`flux generate migration AddRoleToUsers role:string`) and raises an error
-- that says what to pass when the words do not name one.
-- @param words [List<String> the name of the generator, then the words it takes]
-- @return [String path of the file written]
function Tasks.generate(words)
  local entry = generators[words[1]]

  if !entry then
    local usages = {}

    for _, generator in ipairs(Tasks.list.generators) do
      usages[#usages + 1] = 'generate '..generator.name..' '..generator.usage
    end

    local unknown = words[1] ? 'Unknown generator \''..tostring(words[1])..'\'. ' : ''

    error(unknown..'Use '..table.concat(usages, ', or '), 0)
  end

  return entry.run({ unpack(words, 2) })
end

--- Writes a migration file with `ActiveRecord::MigrationGenerator` and prints its path.
-- @param words [List<String> the name of the migration in CamelCase, then its columns as
--   'name:type']
-- @return [String path of the file, relative to the game folder]
function Tasks.generate_migration(words)
  if !words[1] then
    error('The migration needs a name: generate migration <Name> [column:type ...]', 0)
  end

  local path = ActiveRecord.MigrationGenerator.new(words[1], { unpack(words, 2) }):generate()

  print('Generated migration:\n-> '..path)

  return path
end
