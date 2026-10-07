class 'ActiveRecord::MigrationProxy'

--- Creates a stand-in for a migration file, which loads the file only when the
-- migration is needed.
-- @param name [String underscored name of the migration, as found in the file name]
-- @param version [Number]
-- @param filename [String path of the file, relative to the Lua search path]
-- @param scope=nil [String scope suffix of the file name, e.g. the plugin a migration
--   was installed from]
-- @return [ActiveRecord::MigrationProxy(self)]
function ActiveRecord.MigrationProxy:init(name, version, filename, scope)
  self.name = name
  self.version = version
  self.filename = filename
  self.scope = scope
  return self
end

--- Returns the name in CamelCase, as used in the console output.
-- @return [String]
function ActiveRecord.MigrationProxy:camel_name()
  return self.name:camel_case()
end

--- Returns the name of the file without its folder.
-- @return [String]
function ActiveRecord.MigrationProxy:basename()
  return File.name(self.filename)
end

--- Loads the migration file and returns the migration it defines, with the version and
-- the name of the file set on it.
-- @return [ActiveRecord::Migration]
function ActiveRecord.MigrationProxy:load()
  if self.migration then return self.migration end

  local migration = include(self.filename)

  if istable(migration) and migration.static_class and isfunction(migration.new) then
    migration = migration.new()
  end

  if !istable(migration) or !isfunction(migration.migrate) then
    error(
      'ActiveRecord - the migration file '..self.filename..' has to return a migration!\n'..
      'Define one with `local Migration = ActiveRecord.Migration.new()` and end the file with `return Migration`.',
      0
    )
  end

  migration.version = self.version
  migration.name = self:camel_name()
  migration.filename = self.filename

  self.migration = migration

  return migration
end

--- Runs the migration in the given direction.
-- @param direction [String 'up' or 'down']
function ActiveRecord.MigrationProxy:migrate(direction)
  self:load():migrate(direction)
end

--- Checks whether the migration asks to be run outside of a transaction.
-- @return [Boolean]
function ActiveRecord.MigrationProxy:disable_ddl_transaction()
  return self:load().disable_ddl_transaction == true
end

class 'ActiveRecord::MigrationContext'

-- Migration files of packages and plugins, registered through the 'migrations' pipeline.
local sources = {}
local source_list = {}

--- Returns the folder the migrations of the active schema live in, relative to the Lua
-- search path.
-- @return [String e.g. 'reborn/db/migrate/']
function ActiveRecord.MigrationContext.default_migrations_path()
  return Flux.get_schema_folder()..'/db/migrate/'
end

--- Registers a migration file of a package or plugin. Registered files are installed
-- into the schema's migrations folder by #install_migrations.
-- @param path [String path of the file, relative to the Lua search path]
function ActiveRecord.MigrationContext.add_source(path)
  path = (path:gsub('^gamemodes/', ''))

  if sources[path] then return end

  sources[path] = true
  table.insert(source_list, path)
end

--- Returns the registered package and plugin migration files, in the order they were
-- registered in.
-- @return [List<String>]
function ActiveRecord.MigrationContext.sources()
  return source_list
end

--- Splits a migration file name into its parts.
-- @param file_name [String file name or path, e.g. '20190309120000_create_users.admin.lua']
-- @return [Number version, String name, String scope; nil if the name does not match]
function ActiveRecord.MigrationContext.parse_migration_filename(file_name)
  local version, name, scope = File.name(file_name):match('^(%d+)_([_%w]*)%.?([_%w]*)%.lua$')

  if !version then return end

  return tonumber(version), name, scope
end

--- Returns the scope a registered migration file is installed under: the name of the
-- package, plugin or schema folder it comes from.
-- @param path [String path of the file]
-- @return [String]
function ActiveRecord.MigrationContext.scope_of(path)
  local parts = path:split('/')

  -- Drop the file name and the 'migrations' folder.
  table.remove(parts)
  table.remove(parts)

  if parts[#parts] == 'plugin' then
    table.remove(parts)
  end

  return ((parts[#parts] or 'flux'):lower():gsub('[^%w_]', '_'))
end

--- Creates a context, which provides the migrations of one or more folders.
-- @param migrations_paths=nil [List<String> folders to look for migrations in, relative
--   to the Lua search path; the schema's 'db/migrate/' folder by default]
-- @return [ActiveRecord::MigrationContext(self)]
function ActiveRecord.MigrationContext:init(migrations_paths)
  if isstring(migrations_paths) then
    migrations_paths = { migrations_paths }
  end

  self.migrations_paths = migrations_paths or { ActiveRecord.MigrationContext.default_migrations_path() }

  for k, v in ipairs(self.migrations_paths) do
    self.migrations_paths[k] = v:ensure_end('/')
  end

  return self
end

--- Returns the paths of every migration file in the migration folders.
-- @return [List<String>]
function ActiveRecord.MigrationContext:migration_files()
  local files = {}

  for k, path in ipairs(self.migrations_paths) do
    local found = file.Find(path..'*.lua', 'LUA')

    for k2, v in ipairs(found or {}) do
      table.insert(files, path..v)
    end
  end

  return files
end

--- Returns the migrations found in the migration folders, sorted by version. Files whose
-- name is not '<version>_<name>.lua' are ignored. Two migrations with the same version
-- or the same name are an error.
-- @return [List<ActiveRecord::MigrationProxy>]
function ActiveRecord.MigrationContext:migrations()
  local migrations = {}
  local by_version = {}
  local by_name = {}

  for k, file_name in ipairs(self:migration_files()) do
    local version, name, scope = ActiveRecord.MigrationContext.parse_migration_filename(file_name)

    if version then
      if by_version[version] then
        error(
          'ActiveRecord - multiple migrations have the version number '..version..':\n'..
          by_version[version]..'\n'..file_name,
          0
        )
      end

      if by_name[name] then
        error(
          'ActiveRecord - multiple migrations have the name \''..name..'\':\n'..
          by_name[name]..'\n'..file_name..'\n'..
          'Migration names have to be unique. If both come from the same plugin migration, '..
          'delete the newer copy.',
          0
        )
      end

      by_version[version] = file_name
      by_name[name] = file_name

      table.insert(migrations, ActiveRecord.MigrationProxy.new(name, version, file_name, scope))
    end
  end

  table.sort(migrations, function(a, b) return a.version < b.version end)

  return migrations
end

--- Returns the migration with the newest version.
-- @return [ActiveRecord::MigrationProxy or nil if there are no migrations]
function ActiveRecord.MigrationContext:last_migration()
  local migrations = self:migrations()
  return migrations[#migrations]
end

--- Returns the versions of the migrations that have been run.
-- @return [List<Number> sorted, oldest first]
function ActiveRecord.MigrationContext:get_all_versions()
  return ActiveRecord.SchemaMigration:integer_versions()
end

--- Returns the newest version that has been run.
-- @return [Number 0 if no migration has been run]
function ActiveRecord.MigrationContext:current_version()
  local versions = self:get_all_versions()
  return versions[#versions] or 0
end

--- Returns the versions of the migrations that have not been run yet.
-- @return [List<Number>]
function ActiveRecord.MigrationContext:pending_migration_versions()
  local ran = {}

  for k, v in ipairs(self:get_all_versions()) do
    ran[v] = true
  end

  local pending = {}

  for k, v in ipairs(self:migrations()) do
    if !ran[v.version] then
      table.insert(pending, v.version)
    end
  end

  return pending
end

--- Checks whether there are migrations that have not been run yet.
-- @return [Boolean]
function ActiveRecord.MigrationContext:needs_migration()
  return #self:pending_migration_versions() > 0
end

--- Creates a migrator for the migrations of the context without running anything.
-- @param direction='up' [String]
-- @param target_version=nil [Number]
-- @return [ActiveRecord::Migrator]
function ActiveRecord.MigrationContext:open(direction, target_version)
  return ActiveRecord.Migrator.new(direction or 'up', self:migrations(), target_version)
end

--- Runs the migrations that have not been run yet. Given a target version, migrates
-- up or down to it instead.
-- @param target_version=nil [Number/String]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function ActiveRecord.MigrationContext:migrate(target_version)
  target_version = tonumber(target_version)

  if target_version == nil then
    return self:up()
  end

  local current = self:current_version()

  if current < target_version then
    return self:up(target_version)
  elseif current > target_version then
    return self:down(target_version)
  end

  return {}
end

--- Runs the pending migrations up to and including the target version.
-- @param target_version=nil [Number all pending migrations if none is given]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function ActiveRecord.MigrationContext:up(target_version)
  return self:open('up', target_version):migrate()
end

--- Reverts the migrations that have been run, newest first, down to (but not including)
-- the target version.
-- @param target_version=nil [Number every migration if none is given]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were reverted]
function ActiveRecord.MigrationContext:down(target_version)
  return self:open('down', target_version):migrate()
end

--- Runs or reverts a single migration.
-- @param direction [String 'up' or 'down']
-- @param target_version [Number/String version of the migration]
-- @return [List<ActiveRecord::MigrationProxy> the migration, if it was run]
function ActiveRecord.MigrationContext:run(direction, target_version)
  return self:open(direction, tonumber(target_version)):run()
end

--- Moves a number of migrations up or down from the current version.
-- @param direction [String 'up' or 'down']
-- @param steps=1 [Number]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function ActiveRecord.MigrationContext:move(direction, steps)
  steps = tonumber(steps) or 1

  local migrator = self:open(direction)
  local current_version = migrator:current_version()
  local current = migrator:current_migration()

  if current_version != 0 and !current then
    error('ActiveRecord - no migration with version number '..current_version..' found!', 0)
  end

  local migrations = migrator.migrations
  local start_index = 0

  if current then
    start_index = table.KeyFromValue(migrations, current)
  end

  local finish = migrations[start_index + steps]
  local version = finish and finish.version or 0

  if direction == 'down' then
    return self:down(version)
  end

  return self:up(version)
end

--- Reverts the newest migrations.
-- @param steps=1 [Number amount of migrations to revert]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were reverted]
function ActiveRecord.MigrationContext:rollback(steps)
  return self:move('down', steps)
end

--- Runs the next pending migrations.
-- @param steps=1 [Number amount of migrations to run]
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function ActiveRecord.MigrationContext:forward(steps)
  return self:move('up', steps)
end

--- Returns the status of every migration: the ones found in the migration folders and
-- the versions that have been run but have no file anymore.
-- @return [List<Map> entries with status ('up' or 'down'), version (String) and name,
--   sorted by version]
function ActiveRecord.MigrationContext:migrations_status()
  local ran = {}

  for k, v in ipairs(self:get_all_versions()) do
    ran[v] = true
  end

  local status = {}

  for k, v in ipairs(self:migrations()) do
    local name = v.name:gsub('_', ' '):capitalize()

    if v.scope and v.scope != '' then
      name = name..' ('..v.scope..')'
    end

    table.insert(status, {
      status = ran[v.version] and 'up' or 'down',
      version = ActiveRecord.SchemaMigration:normalize_migration_number(v.version),
      name = name
    })

    ran[v.version] = nil
  end

  for version, v in pairs(ran) do
    table.insert(status, {
      status = 'up',
      version = ActiveRecord.SchemaMigration:normalize_migration_number(version),
      name = '********** NO FILE **********'
    })
  end

  table.sort(status, function(a, b) return tonumber(a.version) < tonumber(b.version) end)

  return status
end

--- Records the given version and every older migration as run, without running
-- anything. Used after the schema file has been loaded, which brings the database to
-- the state the migrations up to that version describe.
-- @param version [Number/String]
function ActiveRecord.MigrationContext:assume_migrated_upto_version(version)
  version = tonumber(version)

  if !version then return end

  local ran = {}

  for k, v in ipairs(self:get_all_versions()) do
    ran[v] = true
  end

  if !ran[version] then
    ActiveRecord.SchemaMigration:create_version(version)
  end

  for k, v in ipairs(self:migrations()) do
    if v.version < version and !ran[v.version] then
      ActiveRecord.SchemaMigration:create_version(v.version)
    end
  end
end

--- Returns the version a new migration in the schema's migrations folder gets.
-- @return [String 14-digit version]
function ActiveRecord.MigrationContext:next_migration_number()
  local last = self:last_migration()
  return ActiveRecord.Migration.next_migration_number(last and last.version or 0)
end

local function wrap_unversioned_migration(contents, source)
  return
    '-- This migration comes from '..source..'\n'..
    '-- Its file name has no version, so its statements are wrapped into #change.\n'..
    'local Migration = ActiveRecord.Migration.new()\n\n'..
    'function Migration:change()\n'..
    string.set_indent(contents:trim(), '  ')..'\n'..
    'end\n\n'..
    'return Migration\n'
end

--- Installs the migration files registered with .add_source into the schema's
-- migrations folder (the first of the migration paths): each one is copied under a new
-- version and the scope it came from, e.g. '20190309120000_create_admin_tables.admin.lua'.
-- A migration whose name is already present, under any version or scope, is skipped.
-- Files whose name has no version (e.g. 'CreateFoo.lua') hold bare schema statements,
-- which are wrapped into a migration's #change.
-- @return [List<String> paths of the installed files]
function ActiveRecord.MigrationContext:install_migrations()
  local destination = self.migrations_paths[1]
  local existing = {}
  local last_version = 0

  for k, file_name in ipairs(self:migration_files()) do
    local version, name = ActiveRecord.MigrationContext.parse_migration_filename(file_name)

    if version then
      existing[name] = file_name
      last_version = math.max(last_version, version)
    end
  end

  local installed = {}

  for k, source in ipairs(source_list) do
    local version, name = ActiveRecord.MigrationContext.parse_migration_filename(source)
    local unversioned = version == nil

    if unversioned then
      name = File.name(source):gsub('%.lua$', ''):underscore()
    end

    if !existing[name] then
      local contents = File.read('gamemodes/'..source)

      if contents then
        if unversioned then
          contents = wrap_unversioned_migration(contents, source)
        else
          contents = '-- This migration comes from '..source..' (originally '..version..')\n'..contents
        end

        local new_version = ActiveRecord.Migration.next_migration_number(last_version)
        local scope = ActiveRecord.MigrationContext.scope_of(source)
        local file_name = destination..new_version..'_'..name..'.'..scope..'.lua'

        File.write('gamemodes/'..file_name, contents)

        print('Installed migration '..file_name..' (from '..source..')')

        existing[name] = file_name
        last_version = tonumber(new_version)

        table.insert(installed, file_name)
      end
    end
  end

  return installed
end
