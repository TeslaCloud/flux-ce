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
-- @param settings [Hash database settings; unused]
-- @param on_connected=nil [Function called with the adapter]
function ActiveRecord.Adapters.Sqlite:connect(settings, on_connected)
  if isfunction(on_connected) then on_connected(self) end
end

--- Checks whether the adapter talks to an SQLite database.
-- @return [Boolean always true]
function ActiveRecord.Adapters.Sqlite:is_sqlite()
  return true
end

--- Escapes a string with sql.SQLStr. Single quotes are replaced with backticks first.
-- @param str [String]
-- @return [String escaped string without surrounding quotes]
function ActiveRecord.Adapters.Sqlite:escape(str)
  return sql.SQLStr(string.gsub(str, "'", "`"), true)
end

--- Turns doubled single quotes in a string read from the database back into single ones.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Sqlite:unescape(str)
  return text:gsub("''", "'")
end

--- Runs a raw SQL query on the built-in SQLite database. Always blocks until the query
-- is done, regardless of the sync mode.
-- @param query [String SQL to run]
-- @param callback=nil [Function called with the result rows (an Array of row Hashes, or
--   nil if the query produced no rows), the query string and the time taken in seconds]
-- @param query_type=nil [String unused]
-- @return [Any whatever the callback returns; nothing without a callback or on error]
function ActiveRecord.Adapters.Sqlite:raw_query(query, callback, query_type)
  local query_start = os.clock()
  local result = sql.Query(query)

  if result == false then
    ErrorNoHalt('ActiveRecord - SQLite Query Error!\n')
    long_error('Query: '..query..'\n')
    error_with_traceback(sql.LastError())
  else
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

--- Appends 'SELECT last_insert_rowid()' to insert queries, so that the id of the new
-- row is passed to the query callback.
-- @param query [ActiveRecord::Query unused]
-- @param query_string [String generated SQL]
-- @param query_type [String lowercase query type]
-- @return [String the extended SQL for 'insert' queries, nil for other query types]
function ActiveRecord.Adapters.Sqlite:append_query_string(query, query_string, query_type)
  if query_type == 'insert' then
    return query_string:ensure_end(';')..' SELECT last_insert_rowid();'
  end
end
