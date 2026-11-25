--- Tasks of ActiveRecord, which fpkg runs from the shell without the game server: the database
-- tasks (`fpkg db:migrate`, `fpkg db:rollback STEP=2`, `fpkg db:migrate:status` and so on) and
-- the generators (`fpkg generate migration AddRoleToUsers role:string`, or `fpkg g`), the same
-- as those of the `flux` console command, from the list in `lib/migrator/task_list.lua`. They
-- use the database of the current environment (`fpkg --env development db:migrate` picks one).
-- `db:connect`, which has no description, connects to it without changing anything of the
-- application (see `ActiveRecord.connect`); a database task runs it once its arguments are
-- checked, unless the task needs no connection. A task that fails raises its error, so that
-- fpkg exits with 1.

local tasks = include(TASKSPEC.path..'lib/migrator/task_list.lua')

--- Returns the description of a task for `fpkg tasks`, followed by its usage.
-- @param entry [Map the task, see task_list.lua]
-- @param usage=nil [String usage to show in place of that of the task]
-- @return [String]
local function describe(entry, usage)
  usage = usage or entry.usage

  return usage and entry.description..': '..usage or entry.description
end

--- Runs a database task: checks its arguments before connecting, since `db:connect` already
-- writes to the database and installs migration files and wrong arguments should change
-- nothing, connects when the task needs a connection, then runs it (`Tasks.execute` checks the
-- arguments again, for the console that calls it directly).
-- @param entry [Map the task, see task_list.lua]
-- @param args [Map the arguments fpkg gives the task]
local function run_database_task(entry, args)
  ActiveRecord.Tasks.check(entry.name, args.options, args.words)

  if entry.connection != false then
    Tasks.invoke('db:connect')
  end

  ActiveRecord.Tasks.execute(entry.name, args.options, args.words)
end

namespace('db', function()
  task('connect', 'environment', || -> ActiveRecord.Tasks.connect())

  for _, entry in ipairs(tasks.database) do
    desc(describe(entry))
    task(entry.name, 'environment', args -> run_database_task(entry, args))
  end
end)

local generators = {}

for index, entry in ipairs(tasks.generators) do
  generators[index] = describe(entry, entry.name..' '..entry.usage)
end

desc(table.concat(generators, '; '))
task('generate', 'environment', args -> ActiveRecord.Tasks.generate(args.words))

desc 'Short for generate'
task('g', 'environment', args -> ActiveRecord.Tasks.generate(args.words))
