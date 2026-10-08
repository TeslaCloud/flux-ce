--- Keeps track of the migrations that have been run. Their versions are stored in the
-- 'ar_schema_migrations' table, one row each: the migrator reads them to tell the pending
-- migrations from the ones that have been run, and adds or removes a row whenever a
-- migration is run or reverted. The class is used as it is, without creating objects of
-- it.

class 'ActiveRecord::SchemaMigration'

--- Name of the table that holds the versions of the migrations that have been run.
-- @return [String]
ActiveRecord.SchemaMigration.table_name = 'ar_schema_migrations'

--- Normalizes a version for storage and comparison: a string of digits.
-- @param version [Number/String]
-- @return [String]
function ActiveRecord.SchemaMigration:normalize_migration_number(version)
  return string.format('%.0f', tonumber(version) or 0)
end

--- Creates the 'ar_schema_migrations' table if it does not exist yet.
function ActiveRecord.SchemaMigration:create_table()
  ActiveRecord.SchemaStatements.create_table(self.table_name, { id = false, if_not_exists = true }, function(t)
    t:create('version', (ActiveRecord.adapter.types.string or 'varchar')..' NOT NULL PRIMARY KEY')
  end)
end

--- Drops the 'ar_schema_migrations' table.
function ActiveRecord.SchemaMigration:drop_table()
  ActiveRecord.SchemaStatements.drop_table(self.table_name, { if_exists = true })
end

--- Returns the versions of the migrations that have been run, oldest first.
-- Has to be called while the adapter is in sync mode.
-- @return [List<String>]
function ActiveRecord.SchemaMigration:all_versions()
  local query = ActiveRecord.Database:select(self.table_name)
    query:order('version')
    query:callback(function(result, query_str, time)
      print_query('Schema Migrations Load ('..time..'s)', query_str)

      local versions = {}

      if istable(result) then
        for k, v in ipairs(result) do
          table.insert(versions, self:normalize_migration_number(v.version))
        end
      end

      return versions
    end)
  return query:execute() or {}
end

--- Returns the versions of the migrations that have been run as numbers, oldest first.
-- @return [List<Number>]
function ActiveRecord.SchemaMigration:integer_versions()
  local versions = {}

  for k, v in ipairs(self:all_versions()) do
    table.insert(versions, tonumber(v))
  end

  return versions
end

--- Records a migration version as run.
-- @param version [Number/String]
function ActiveRecord.SchemaMigration:create_version(version)
  local query = ActiveRecord.Database:insert(self.table_name)
    query:insert('version', self:normalize_migration_number(version))
    query:callback(function(result, query_str, time)
      print_query('Schema Migration Create ('..time..'s)', query_str)
    end)
  query:execute()
end

--- Removes a migration version from the list of the ones that have been run.
-- @param version [Number/String]
function ActiveRecord.SchemaMigration:delete_version(version)
  local query = ActiveRecord.Database:delete(self.table_name)
    query:where('version', self:normalize_migration_number(version))
    query:callback(function(result, query_str, time)
      print_query('Schema Migration Delete ('..time..'s)', query_str)
    end)
  query:execute()
end

--- Forgets every migration version that has been run.
function ActiveRecord.SchemaMigration:delete_all_versions()
  local query = ActiveRecord.Database:delete(self.table_name)
    query:callback(function(result, query_str, time)
      print_query('Schema Migration Delete ('..time..'s)', query_str)
    end)
  query:execute()
end
