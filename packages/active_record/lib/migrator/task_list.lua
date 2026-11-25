--- The tasks of ActiveRecord, written once for every place that offers them: `ActiveRecord.Tasks`
-- runs them, the `flux` console command lists them in its usage text, and the `taskspec.lua` of
-- the package turns them into fpkg's tasks (`fpkg db:migrate`). fpkg loads that file before
-- anything of Flux exists, so this one holds plain data, and functions that reach ActiveRecord
-- only when they are called.
--
-- `database` lists the database tasks, run as `db:<name>`, in the order the usage text shows
-- them. Every entry has its `name`, its `usage`, a `description` and `run`, called with the
-- options of the task; `connection = false` marks a task that runs without a connected
-- database. The usage names the options the task takes: `KEY=x` one it needs, `[KEY=x]` one
-- it may be given, where `x` stands for the version of a migration and `n` for a number of
-- migrations. `generators` lists what `generate <name>` writes, with the words its `run`
-- takes in `usage`.
-- @module [ActiveRecord.Tasks]

return {
  database = {
    {
      name = 'migrate',
      usage = '[VERSION=x]',
      description = 'Run the pending migrations, or migrate to a version',
      run = env -> ActiveRecord.Tasks.migrate(env.VERSION)
    },
    {
      name = 'migrate:status',
      description = 'List the migrations and whether they have been run',
      run = _env -> ActiveRecord.Tasks.migrate_status()
    },
    {
      name = 'migrate:up',
      usage = 'VERSION=x',
      description = 'Run a single migration',
      run = env -> ActiveRecord.Tasks.migrate_up(env.VERSION)
    },
    {
      name = 'migrate:down',
      usage = 'VERSION=x',
      description = 'Revert a single migration',
      run = env -> ActiveRecord.Tasks.migrate_down(env.VERSION)
    },
    {
      name = 'migrate:redo',
      usage = '[STEP=n] [VERSION=x]',
      description = 'Revert and re-run the newest migration(s), or the one of VERSION',
      run = env -> ActiveRecord.Tasks.redo(env.STEP, env.VERSION)
    },
    {
      name = 'rollback',
      usage = '[STEP=n]',
      description = 'Revert the newest migration(s)',
      run = env -> ActiveRecord.Tasks.rollback(env.STEP)
    },
    {
      name = 'forward',
      usage = '[STEP=n]',
      description = 'Run the next pending migration(s)',
      run = env -> ActiveRecord.Tasks.forward(env.STEP)
    },
    {
      name = 'version',
      description = 'Print the current schema version',
      run = _env -> ActiveRecord.Tasks.version()
    },
    {
      name = 'schema:dump',
      description = 'Write the schema into db/schema.lua',
      run = _env -> ActiveRecord.Tasks.schema_dump()
    },
    {
      name = 'schema:load',
      description = 'Create the tables of db/schema.lua',
      run = _env -> ActiveRecord.Tasks.schema_load()
    },
    {
      name = 'prepare',
      description = 'Bring the database up to date as the server does when it starts',
      run = _env -> ActiveRecord.Tasks.prepare()
    },
    {
      name = 'create',
      description = 'Create the database (PostgreSQL only)',
      connection = false,
      run = _env -> ActiveRecord.Database:setup(ActiveRecord.db_settings)
    },
    {
      name = 'drop',
      description = 'Drop the database (PostgreSQL only)',
      connection = false,
      run = _env -> ActiveRecord.Database:drop_database(ActiveRecord.db_settings)
    }
  },
  generators = {
    {
      name = 'migration',
      usage = '<Name> [column:type ...]',
      description = 'Write a migration file into db/migrate',
      run = words -> ActiveRecord.Tasks.generate_migration(words)
    }
  }
}
