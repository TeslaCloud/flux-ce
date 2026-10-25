--- Migration that gives the tables of an SQLite database the foreign keys that the schema
-- declares for them and makes their primary keys AUTOINCREMENT, as `create_table` and
-- `add_foreign_key` make them on SQLite. A database whose tables have both already, such as
-- a new one, is left as it is; on PostgreSQL and MySQL the migration does nothing.
--
-- Before a foreign key is created, the rows that refer to rows that do not exist are dealt
-- with by its ON DELETE action: they are deleted for 'cascade' and their column is set to
-- NULL for 'nullify'. A foreign key with another action whose rows refer to rows that do not
-- exist is not created, and a warning names its table, its column and the number of those
-- rows. See `add_missing_foreign_keys` and `add_autoincrement` in the schema statements of
-- ActiveRecord.
--
-- Every table is made AUTOINCREMENT, not only those that other tables refer to: rows of
-- other tables, logs and the data of plugins keep ids without a foreign key, and a table is
-- rebuilt at most once, together with its foreign keys. The internal `ar_*` tables of
-- ActiveRecord are left out. Rolling back leaves the tables as they are.

local CompleteSqliteTables = ActiveRecord.Migration.new()

--- Creates the missing foreign keys and makes the primary key of every table AUTOINCREMENT.
function CompleteSqliteTables:up()
  add_missing_foreign_keys()

  local table_names = table.GetKeys(ActiveRecord.schema)

  table.sort(table_names)

  for _, table_name in ipairs(table_names) do
    if !table_name:start_with('ar_') then
      add_autoincrement(table_name)
    end
  end
end

--- Leaves the foreign keys and the AUTOINCREMENT primary keys in place: the earlier
-- migrations declare them, and the tables keep their rows and ids either way.
function CompleteSqliteTables:down()
end

return CompleteSqliteTables
