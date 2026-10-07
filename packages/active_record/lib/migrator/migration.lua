class 'ActiveRecord::Migration'

--- Creates a migration. Override #change (or #up and #down) to describe what it does.
-- ```
-- local Migration = ActiveRecord.Migration.new(20190309120000)
--   function Migration:change()
--     add_column('users', { 'role', type = 'string', default = '\'user\'' })
--   end
-- return Migration
-- ```
-- @param version=0 [Number/String schema version after this migration, normally a
--   YYYYMMDDHHMMSS timestamp]
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:init(version)
  self.version = version or 0
  return self
end

--- Describes the schema changes of the migration. Does nothing by default and is meant
-- to be overridden.
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:change()
  return self
end

--- Applies the migration by calling #change.
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:up()
  self:change()
  return self
end

--- Reverts the migration. Does nothing by default and is meant to be overridden.
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:down()
  return self
end
