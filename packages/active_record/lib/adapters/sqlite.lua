--- Adapter for the SQLite database built into Garry's Mod (the `sql` library). It is the
-- default: it is used when the database settings name the 'sqlite' or 'sqlite3' adapter,
-- or none at all. It needs no connection and no binary module, every query blocks until
-- it is done, and schema changes can be rolled back, so migrations run in a transaction.
-- Foreign keys are enforced: the adapter turns their enforcement on when it connects, and it
-- lasts as long as the connection, which Garry's Mod keeps open while the server runs.
-- Primary keys are AUTOINCREMENT, so the id of a deleted row is never given to a new one.

class 'ActiveRecord::Adapters::Sqlite' extends 'ActiveRecord::Adapters::Abstract'

ActiveRecord.Adapters.Sqlite.types = {
  primary_key = 'INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL',
  string = 'varchar',
  text = 'text',
  integer = 'integer',
  float = 'float',
  decimal = 'decimal',
  datetime = 'datetime',
  timestamp = 'datetime',
  time = 'time',
  date = 'date',
  binary = 'blob',
  boolean = 'boolean',
  json = 'json'
}

ActiveRecord.Adapters.Sqlite._sql_syntax = 'sqlite'

--- Turns on the enforcement of foreign keys and calls the callback right away, since the
-- SQLite database built into Garry's Mod needs no connection. Rows that broke a foreign key
-- before stay as they are; only the rows written from then on are checked.
-- @param _settings [Map database settings; unused]
-- @param on_connected=nil [Function called with the adapter]
function ActiveRecord.Adapters.Sqlite:connect(_settings, on_connected)
  self:enable_foreign_keys()

  if isfunction(on_connected) then on_connected(self) end
end

local function rows(result)
  return result
end

--- Checks whether foreign keys are enforced right now.
-- @return [Boolean]
function ActiveRecord.Adapters.Sqlite:foreign_keys_enabled()
  local result = self:raw_query('PRAGMA foreign_keys;', rows)

  return istable(result) and istable(result[1]) and tonumber(result[1].foreign_keys) == 1
end

--- Stops enforcing foreign keys. SQLite ignores this inside of a transaction, so it has to
-- be called before one is started.
-- @return [Boolean whether the enforcement was on and has been turned off]
function ActiveRecord.Adapters.Sqlite:disable_foreign_keys()
  if !self:foreign_keys_enabled() then return false end

  self:raw_query('PRAGMA foreign_keys = OFF;')

  return !self:foreign_keys_enabled()
end

--- Enforces foreign keys. SQLite ignores this inside of a transaction.
function ActiveRecord.Adapters.Sqlite:enable_foreign_keys()
  self:raw_query('PRAGMA foreign_keys = ON;')
end

--- Lists the rows that refer to rows that do not exist through a foreign key.
-- @param adapter [ActiveRecord::Adapters::Sqlite]
-- @param table_name=nil [String only list the rows of this table]
-- @return [List<Map> the rows, as PRAGMA foreign_key_check returns them]
local function list_violations(adapter, table_name)
  local query = 'PRAGMA foreign_key_check'

  if isstring(table_name) then
    query ..= '('..adapter:quote_name(table_name)..')'
  end

  local result = adapter:raw_query(query..';', rows)

  return istable(result) and result or {}
end

local function violation_key(violation)
  return tostring(violation.table)..' -> '..tostring(violation.parent)..' #'..tostring(violation.fkid)
end

local function count_violations(violations)
  local counts = {}

  for _, violation in ipairs(violations) do
    local key = violation_key(violation)

    counts[key] = (counts[key] or 0) + 1
  end

  return counts
end

--- Counts the rows that refer to rows that do not exist through a foreign key.
-- @param table_name=nil [String only count the rows of this table]
-- @return [Map numbers of such rows, keyed by the table, the referenced table and the
--   foreign key]
function ActiveRecord.Adapters.Sqlite:foreign_key_violations(table_name)
  return count_violations(list_violations(self, table_name))
end

--- Raises an error listing the rows that refer to rows that do not exist through a foreign
-- key, if there are more of them than before.
-- @param table_name=nil [String only check the rows of this table]
-- @param before=nil [Map what #foreign_key_violations returned before; these rows are not
--   reported]
function ActiveRecord.Adapters.Sqlite:check_foreign_keys(table_name, before)
  local violations = list_violations(self, table_name)
  local counts = count_violations(violations)
  local new_keys = {}
  local total = 0

  for key, amount in pairs(counts) do
    local added = amount - (istable(before) and before[key] or 0)

    if added > 0 then
      new_keys[key] = true
      total += added
    end
  end

  if total == 0 then return end

  local lines = {}

  for _, violation in ipairs(violations) do
    if #lines >= 10 then break end

    if new_keys[violation_key(violation)] then
      lines[#lines + 1] = tostring(violation.table)..' (row '..tostring(violation.rowid)
        ..') refers to a row of '..tostring(violation.parent)..' that does not exist'
    end
  end

  error('ActiveRecord - '..total..' row(s) break a foreign key:\n'..table.concat(lines, '\n'), 0)
end

--- Checks whether the adapter talks to an SQLite database.
-- @return [Boolean always true]
function ActiveRecord.Adapters.Sqlite:is_sqlite()
  return true
end

--- SQLite can roll back schema changes.
-- @return [Boolean always true]
function ActiveRecord.Adapters.Sqlite:supports_ddl_transactions()
  return true
end

--- Escapes a string with sql.SQLStr, which doubles its single quotes.
-- @param str [String]
-- @return [String escaped string without surrounding quotes]
function ActiveRecord.Adapters.Sqlite:escape(str)
  return sql.SQLStr(str, true)
end

--- Quotes an identifier such as a table or column name with double quotes, doubling the
-- double quotes in it.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Sqlite:quote_name(str)
  return '"'..string.gsub(str, '"', '""')..'"'
end

--- Turns doubled single quotes in a string read from the database back into single ones.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Sqlite:unescape(str)
  return (str:gsub("''", "'"))
end

--- Runs a raw SQL query on the built-in SQLite database. Always blocks until the query
-- is done, regardless of the sync mode.
-- A query that is given bindings, even an empty list of them, is run with
-- sql.QueryTyped: numbers come back as numbers and NULL columns are left out of their
-- rows. Without bindings it is run with sql.Query, which returns every value as a
-- string, but takes several statements at once.
-- @param query [String SQL to run]
-- @param callback=nil [Function called with the result rows (a List of row Maps; nil
--   if a query without bindings produced no rows), the query string, the time taken
--   in seconds and the bindings. For 'insert' queries the result is a single row with
--   the id of the new row instead]
-- @param query_type=nil [String lowercase query type, e.g. 'insert']
-- @param bindings=nil [List values of the ? placeholders in the query. A query that is
--   given bindings has to be a single statement]
-- @param error_callback=nil [Function called with the error text if the query fails]
-- @return [Any whatever the callback returns; nothing without a callback or on error]
function ActiveRecord.Adapters.Sqlite:raw_query(query, callback, query_type, bindings, error_callback)
  local query_start = os.clock()
  local result = nil

  if bindings then
    result = sql.QueryTyped(query, unpack(bindings))
  else
    result = sql.Query(query)
  end

  if result == false then
    return self:report_failure(query, sql.LastError(), error_callback)
  else
    if query_type == 'insert' then
      result = { { id = tonumber(sql.QueryValue('SELECT last_insert_rowid()')) } }
    end

    if callback then
      local status, a, b, c, d = pcall(callback, result, query, math.Round(os.clock() - query_start, 3), bindings)

      if !status then
        ErrorNoHalt('ActiveRecord - SQLite Callback Error!\n')
        error_with_traceback(a)
      end

      return a, b, c, d
    end
  end
end
