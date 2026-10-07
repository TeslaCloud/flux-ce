ActiveRecord.Adapters = ActiveRecord.Adapters or {}

class 'ActiveRecord::Adapters::Abstract'

ActiveRecord.Adapters.Abstract._queue = {}
ActiveRecord.Adapters.Abstract._connected = false
ActiveRecord.Adapters.Abstract._sync = false
ActiveRecord.Adapters.Abstract._sql_syntax = 'abstract'

--- Resets the connection state, the sync flag and the query queue of a new adapter.
function ActiveRecord.Adapters.Abstract:init()
  self._connected = false
  self._sync = false
  self._queue = {}
end

--- Switches the adapter between synchronous (blocking) and asynchronous query mode.
-- In sync mode #raw_query waits for the result and returns what the query callback returns.
-- @param sync [Boolean true to make queries blocking]
-- @return [ActiveRecord::Adapters::Abstract(self)]
function ActiveRecord.Adapters.Abstract:sync(sync)
  self._sync = sync
  return self
end

--- Returns the SQL dialect the adapter speaks.
-- @return [String 'abstract', 'mysql', 'postgresql' or 'sqlite']
function ActiveRecord.Adapters.Abstract:get_sql_std()
  return self._sql_syntax
end

--- Checks whether the adapter talks to a PostgreSQL database.
-- @return [Boolean false, unless overridden by the adapter]
function ActiveRecord.Adapters.Abstract:is_postgres()
  return false
end

--- Checks whether the adapter talks to a MySQL database.
-- @return [Boolean false, unless overridden by the adapter]
function ActiveRecord.Adapters.Abstract:is_mysql()
  return false
end

--- Checks whether the adapter talks to an SQLite database.
-- @return [Boolean false, unless overridden by the adapter]
function ActiveRecord.Adapters.Abstract:is_sqlite()
  return false
end

--- Connects to the database. The abstract implementation only marks the adapter as
-- connected and never calls the callback; real adapters override it.
-- @param config [Map database settings: host, user, password, port, database]
-- @param on_connected [Function called with the adapter once the connection is ready]
function ActiveRecord.Adapters.Abstract:connect(config, on_connected)
  self._connected = true
end

--- Closes the database connection. The abstract implementation only clears the
-- connected flag.
-- @param config=nil [Map unused]
function ActiveRecord.Adapters.Abstract:disconnect(config)
  self._connected = false
end

--- Escapes a string for safe use inside an SQL string literal.
-- The abstract implementation returns the string unchanged.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Abstract:escape(str)
  return str
end

--- Reverts #escape on a string that was read back from the database.
-- The abstract implementation returns the string unchanged.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Abstract:unescape(str)
  return str
end

--- Escapes a string and wraps it in single quotes, producing an SQL string literal.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Abstract:quote(str)
  return "'"..self:escape(str).."'"
end

--- Quotes an identifier such as a table or column name.
-- The abstract implementation returns the name unchanged.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Abstract:quote_name(str)
  return str
end

--- Returns the placeholder that stands for a bind parameter in the SQL of the adapter.
-- @param index [Number position of the parameter in the list of bindings, starting at 1]
-- @return [String '?', unless overridden by the adapter]
function ActiveRecord.Adapters.Abstract:placeholder(index)
  return '?'
end

--- Sends a raw SQL string to the database. Does nothing in the abstract adapter.
-- Values are best kept out of the SQL itself and passed as bindings instead, which take
-- the place of the #placeholder of the adapter in the query and need no escaping.
-- @param query [String SQL to run]
-- @param callback=nil [Function called with the result rows, the query string and the
--   time the query took in seconds]
-- @param query_type=nil [String lowercase query type, e.g. 'select' or 'insert']
-- @param bindings=nil [List values of the bind parameters of the query, in the order of
--   their placeholders; strings, numbers and booleans are supported. A query that is
--   given bindings has to be a single statement]
function ActiveRecord.Adapters.Abstract:raw_query(query, callback, query_type, bindings)
end

--- Puts a raw SQL string into the queue. Queued queries are run one at a time by #think.
-- @param query [String SQL to run; anything that is not a string is ignored]
-- @param callback=nil [Function passed on to #raw_query]
-- @param query_type=nil [String passed on to #raw_query]
-- @param bindings=nil [List passed on to #raw_query]
function ActiveRecord.Adapters.Abstract:queue(query, callback, query_type, bindings)
  if isstring(query) then
    table.insert(self._queue, { query, callback, query_type, bindings })
  end
end

--- Hook called by ActiveRecord::Query#execute before the SQL string is built, so that
-- the adapter can adjust the query object. Does nothing in the abstract adapter.
-- @param query [ActiveRecord::Query]
-- @param query_type [String lowercase query type, e.g. 'create']
-- @param queue=nil [Boolean whether the query will be queued instead of run right away]
function ActiveRecord.Adapters.Abstract:append_query(query, query_type, queue)
end

--- Hook called by ActiveRecord::Query#execute once the SQL string is built. Adapters may
-- return a string to replace it. Does nothing in the abstract adapter.
-- @param query [ActiveRecord::Query]
-- @param query_string [String generated SQL, nil if the query could not be built]
-- @param query_type [String lowercase query type, e.g. 'insert']
function ActiveRecord.Adapters.Abstract:append_query_string(query, query_string, query_type)
end

--- Hook called after a column is added to a 'create' or 'change' query through one of
-- the column type methods (t:string, t:integer, ...). Does nothing in the abstract adapter.
-- @param query [ActiveRecord::Query query the column was added to]
-- @param column [String column name]
-- @param args [Map column options, such as null and default]
-- @param obj [ActiveRecord::Query object the column type method was generated for]
-- @param type [String abstract column type, e.g. 'primary_key']
-- @param def [String adapter-specific SQL type definition]
function ActiveRecord.Adapters.Abstract:create_column(query, column, args, obj, type, def)
end

--- Runs the oldest queued query, if there is one. Called once a second by a timer.
function ActiveRecord.Adapters.Abstract:think()
  if #self._queue > 0 then
    if istable(self._queue[1]) then
      local queue_obj = self._queue[1]
      local query_string = queue_obj[1]

      if isstring(query_string) then
        self:raw_query(query_string, queue_obj[2], queue_obj[3], queue_obj[4])
      end

      table.remove(self._queue, 1)
    end
  end
end

--- Checks whether a query result contains at least one row.
-- @param result [Any query result]
-- @return [Boolean]
function ActiveRecord.Adapters.Abstract:is_result(result)
  return istable(result) and #result > 0
end

--- Called when the database connects successfully. Runs ActiveRecord's startup in sync
-- mode and fires the 'DatabaseConnected' hook.
function ActiveRecord.Adapters.Abstract:on_connected()
  self._connected = true
  self:sync(true)

  ActiveRecord.on_connected()
  hook.Run('DatabaseConnected')

  self:sync(false)
end

--- Called when the database connection fails. Prints the error and fires the
-- 'DatabaseConnectionFailed' hook.
-- @param error_text [String error reported by the database module]
function ActiveRecord.Adapters.Abstract:on_connection_failed(error_text)
  ErrorNoHalt('ActiveRecord - Unable to connect to the database!\n'..error_text..'\n')

  if error_text:find('does not exist') and !self:is_sqlite() then
    ErrorNoHalt('HINT:\ntry running "flux db:create" to create the databases.\n\n')
  end

  hook.Run('DatabaseConnectionFailed', error_text)
end

--- Checks whether or not the adapter is connected to a database.
-- @return [Boolean]
function ActiveRecord.Adapters.Abstract:connected()
  return self._connected
end
