--- Adapter for the SQLite database built into Garry's Mod (the `sql` library). It is the
-- default: it is used when the database settings name the 'sqlite' or 'sqlite3' adapter,
-- or none at all. It needs no connection and no binary module, every query blocks until
-- it is done, and schema changes can be rolled back, so migrations run in a transaction.

class 'ActiveRecord::Adapters::Sqlite' extends 'ActiveRecord::Adapters::Abstract'

ActiveRecord.Adapters.Sqlite.types = {
  primary_key = 'INTEGER PRIMARY KEY NOT NULL',
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

--- Calls the callback right away, since the SQLite database built into Garry's Mod
-- needs no connection.
-- @param settings [Map database settings; unused]
-- @param on_connected=nil [Function called with the adapter]
function ActiveRecord.Adapters.Sqlite:connect(settings, on_connected)
  if isfunction(on_connected) then on_connected(self) end
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

--- Escapes a string with sql.SQLStr. Single quotes are replaced with backticks first.
-- @param str [String]
-- @return [String escaped string without surrounding quotes]
function ActiveRecord.Adapters.Sqlite:escape(str)
  return sql.SQLStr(string.gsub(str, "'", '`'), true)
end

--- Turns doubled single quotes in a string read from the database back into single ones.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Sqlite:unescape(str)
  return text:gsub("''", "'")
end

--- Runs a raw SQL query on the built-in SQLite database. Always blocks until the query
-- is done, regardless of the sync mode.
-- A query that is given bindings, even an empty list of them, is run with
-- sql.QueryTyped: numbers come back as numbers and NULL columns are left out of their
-- rows. Without bindings it is run with sql.Query, which returns every value as a
-- string, but takes several statements at once.
-- @param query [String SQL to run]
-- @param callback=nil [Function called with the result rows (a List of row Maps; nil
--   if a query without bindings produced no rows), the query string and the time taken
--   in seconds. For 'insert' queries the result is a single row with the id of the new
--   row instead]
-- @param query_type=nil [String lowercase query type, e.g. 'insert']
-- @param bindings=nil [List values of the ? placeholders in the query. A query that is
--   given bindings has to be a single statement]
-- @return [Any whatever the callback returns; nothing without a callback or on error]
function ActiveRecord.Adapters.Sqlite:raw_query(query, callback, query_type, bindings)
  local query_start = os.clock()
  local result = nil

  if bindings then
    result = sql.QueryTyped(query, unpack(bindings))
  else
    result = sql.Query(query)
  end

  if result == false then
    return self:query_failed(query, sql.LastError())
  else
    if query_type == 'insert' then
      result = { { id = tonumber(sql.QueryValue('SELECT last_insert_rowid()')) } }
    end

    if callback then
      local status, a, b, c, d = pcall(callback, result, query, math.Round(os.clock() - query_start, 3))

      if !status then
        ErrorNoHalt('ActiveRecord - SQLite Callback Error!\n')
        error_with_traceback(a)
      end

      return a, b, c, d
    end
  end
end
