include 'migration.lua'
include 'command_recorder.lua'
include 'schema_migration.lua'
include 'migration_context.lua'
include 'schema.lua'
include 'migration_generator.lua'
include 'tasks.lua'

class 'ActiveRecord::Migrator'

--- Creates a migrator, which runs a list of migrations in one direction. Normally
-- created by ActiveRecord::MigrationContext.
-- @param direction [String 'up' or 'down']
-- @param migrations [List<ActiveRecord::MigrationProxy> sorted by version]
-- @param target_version=nil [Number version to migrate to]
-- @return [ActiveRecord::Migrator(self)]
function ActiveRecord.Migrator:init(direction, migrations, target_version)
  self.direction = direction
  self.target_version = target_version and tonumber(target_version) or nil
  self.migrations = table.Copy(migrations or {})

  table.sort(self.migrations, function(a, b) return a.version < b.version end)

  -- Going down, the migrations are visited newest first.
  if direction == 'down' then
    self.migrations = table.Reverse(self.migrations)
  end

  return self
end

--- Checks whether the migrator migrates up.
-- @return [Boolean]
function ActiveRecord.Migrator:up()
  return self.direction == 'up'
end

--- Checks whether the migrator migrates down.
-- @return [Boolean]
function ActiveRecord.Migrator:down()
  return self.direction == 'down'
end

--- Returns the versions of the migrations that have been run, as a set.
-- @return [Map version to true]
function ActiveRecord.Migrator:migrated()
  if !self.migrated_versions then
    self.migrated_versions = {}

    for k, v in ipairs(ActiveRecord.SchemaMigration:integer_versions()) do
      self.migrated_versions[v] = true
    end
  end

  return self.migrated_versions
end

--- Checks whether a migration has been run.
-- @param migration [ActiveRecord::MigrationProxy]
-- @return [Boolean]
function ActiveRecord.Migrator:ran(migration)
  return self:migrated()[migration.version] == true
end

--- Returns the newest version that has been run.
-- @return [Number 0 if no migration has been run]
function ActiveRecord.Migrator:current_version()
  local newest = 0

  for version, v in pairs(self:migrated()) do
    if version > newest then newest = version end
  end

  return newest
end

--- Returns the migration of the newest version that has been run.
-- @return [ActiveRecord::MigrationProxy or nil]
function ActiveRecord.Migrator:current_migration()
  local current = self:current_version()

  for k, v in ipairs(self.migrations) do
    if v.version == current then return v end
  end
end

--- Returns the migration of the target version.
-- @return [ActiveRecord::MigrationProxy or nil]
function ActiveRecord.Migrator:target()
  if !self.target_version then return end

  for k, v in ipairs(self.migrations) do
    if v.version == self.target_version then return v end
  end
end

--- Checks whether a target version was given that no migration has.
-- @return [Boolean]
function ActiveRecord.Migrator:invalid_target()
  return self.target_version != nil and self.target_version != 0 and self:target() == nil
end

--- Returns the migrations that have not been run yet, oldest first.
-- @return [List<ActiveRecord::MigrationProxy>]
function ActiveRecord.Migrator:pending_migrations()
  local pending = {}

  for k, v in ipairs(self.migrations) do
    if !self:ran(v) then
      table.insert(pending, v)
    end
  end

  if self:down() then
    pending = table.Reverse(pending)
  end

  return pending
end

--- Returns the migrations that #migrate runs: going up, the pending migrations up to
-- the target; going down, the migrations that have been run, from the current one down
-- to (but not including) the target.
-- @return [List<ActiveRecord::MigrationProxy>]
function ActiveRecord.Migrator:runnable()
  local start = 1
  local finish = #self.migrations
  local target = self:target()

  if self:down() then
    local current = self:current_migration()

    if current then
      start = table.KeyFromValue(self.migrations, current)
    end
  end

  if target then
    finish = table.KeyFromValue(self.migrations, target)
  end

  local runnable = {}

  for i = start, finish do
    table.insert(runnable, self.migrations[i])
  end

  -- Skip the target when going down, so that the database is left at that version.
  if self:down() and target then
    table.remove(runnable)
  end

  local selected = {}

  for k, v in ipairs(runnable) do
    if self:ran(v) == self:down() then
      table.insert(selected, v)
    end
  end

  return selected
end

--- Runs every runnable migration.
-- @return [List<ActiveRecord::MigrationProxy> migrations that were run]
function ActiveRecord.Migrator:migrate()
  if self:invalid_target() then
    error('ActiveRecord - no migration with version number '..self.target_version..' found!', 0)
  end

  local executed = {}

  for k, v in ipairs(self:runnable()) do
    if self:execute_migration_in_transaction(v) then
      table.insert(executed, v)
    end
  end

  return executed
end

--- Runs only the migration of the target version.
-- @return [List<ActiveRecord::MigrationProxy> the migration, if it was run]
function ActiveRecord.Migrator:run()
  local migration = self:target()

  if !migration then
    error('ActiveRecord - no migration with version number '..tostring(self.target_version)..' found!', 0)
  end

  if self:execute_migration_in_transaction(migration) then
    return { migration }
  end

  return {}
end

--- Runs a migration in the direction of the migrator, inside of a transaction if the
-- database supports it. Records the version as run (or forgets it) afterward. A failed
-- migration is rolled back and raises an error, so that no later migration runs.
-- @param migration [ActiveRecord::MigrationProxy]
-- @return [Boolean whether the migration was run; false if it had been run (or
--   reverted) already]
function ActiveRecord.Migrator:execute_migration_in_transaction(migration)
  if self:down() and !self:ran(migration) then return false end
  if self:up() and self:ran(migration) then return false end

  local adapter = ActiveRecord.adapter
  local use_transaction = adapter:supports_ddl_transactions() and !migration:disable_ddl_transaction()
  local snapshot = {
    schema = table.Copy(ActiveRecord.schema),
    metadata = table.Copy(ActiveRecord.metadata)
  }

  Flux.dev_print('ActiveRecord - Migrating to '..migration:camel_name()..' ('..migration.version..')')

  adapter.last_error = nil
  adapter:raise_errors(true)

  if use_transaction then
    adapter:begin_transaction()
  end

  local success, exception = pcall(function()
    migration:migrate(self.direction)

    if adapter.last_error then
      error(adapter.last_error, 0)
    end

    self:record_version_state_after_migrating(migration.version)
  end)

  adapter:raise_errors(false)

  if success then
    if use_transaction then
      adapter:commit_transaction()
    end

    return true
  end

  if use_transaction then
    adapter:rollback_transaction()
  end

  ActiveRecord.schema = snapshot.schema
  ActiveRecord.metadata = snapshot.metadata
  ActiveRecord.Model:populate()

  error(
    'An error has occurred, '..(use_transaction and 'this and ' or '')..'all later migrations canceled:\n\n'..
    tostring(exception),
    0
  )
end

--- Records that a migration was run, or that it was reverted.
-- @param version [Number]
function ActiveRecord.Migrator:record_version_state_after_migrating(version)
  if self:down() then
    self:migrated()[version] = nil
    ActiveRecord.SchemaMigration:delete_version(version)
  else
    self:migrated()[version] = true
    ActiveRecord.SchemaMigration:create_version(version)
  end
end
