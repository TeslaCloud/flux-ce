--- The schema definition that the schema file is written in. The generated
-- `db/schema.lua` calls `ActiveRecord.Schema:define` with the version of the schema and a
-- function whose schema statements create every table, index and foreign key. Loading
-- the file, with `flux db:schema:load` or when the server starts with an empty database,
-- builds the whole database at once and records the migrations up to that version as run.
--
-- Schema files of the older form, which define a 'Structure' object with a
-- `create_tables` method, are still recognized, but they cannot be loaded.

class 'ActiveRecord::Schema'

--- Creates a schema object. Only used by schema files that hold a 'Structure' object
-- with a #create_tables method.
-- @param version [Number/String schema version]
function ActiveRecord.Schema:init(version)
  self.version = version
end

--- Defines the schema of the database. Used by the generated 'db/schema.lua' file,
-- which is loaded with `flux db:schema:load` or when a fresh database is set up.
-- The statements of the callback are run right away, after which the given version and
-- every older migration are recorded as run.
-- ```
-- ActiveRecord.Schema:define({ version = 20190309120000 }, function()
--   create_table('users', { force = true }, function(t)
--     t:string { 'steam_id', null = false }
--     t:timestamps()
--   end)
--
--   add_index('users', { 'steam_id' }, { name = 'users_steam_id_index' })
-- end)
-- ```
-- Called with a version alone, as the schema files that hold a 'Structure' object do,
-- it returns a schema object instead and runs nothing.
-- @param info [Map/Number/String a table with the version, or the version itself]
-- @param callback=nil [Function makes the schema statements]
-- @return [ActiveRecord::Schema only for the one-argument form]
function ActiveRecord.Schema:define(info, callback)
  if !istable(info) then
    return ActiveRecord.Schema.new(info)
  end

  ActiveRecord.Schema.load(info, callback)
end

--- Creates all tables of the schema. Does nothing; the schema files that hold a
-- 'Structure' object override it.
-- @return [ActiveRecord::Schema(self)]
function ActiveRecord.Schema:create_tables()
  return self
end

--- Runs the statements of a schema definition and records the migrations up to its
-- version as run.
-- @warning [Internal]
-- @param info [Map version]
-- @param callback [Function]
function ActiveRecord.Schema.load(info, callback)
  if !ActiveRecord.ready then
    error('ActiveRecord - the schema can only be loaded once ActiveRecord is ready!', 0)
  end

  local adapter = ActiveRecord.adapter

  adapter.last_error = nil
  adapter:raise_errors(true)

  local success, exception = pcall(callback)

  adapter:raise_errors(false)

  if !success then
    error(exception, 0)
  end

  ActiveRecord.SchemaMigration:create_table()

  if info.version then
    local context = ActiveRecord.migration_context or ActiveRecord.MigrationContext.new()
    context:assume_migrated_upto_version(info.version)
  end

  ActiveRecord.Model:populate()
end
