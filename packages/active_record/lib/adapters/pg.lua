class 'ActiveRecord::Adapters::Pg' extends 'ActiveRecord::Adapters::Abstract'

ActiveRecord.Adapters.Pg.types = {
  primary_key = 'bigserial primary key',
  string = 'character varying',
  text = 'text',
  integer = 'integer',
  float = 'float',
  decimal = 'decimal',
  datetime = 'timestamp',
  timestamp = 'timestamp',
  time = 'time',
  date = 'date',
  binary = 'bytea',
  boolean = 'boolean',
  json = 'json'
}

ActiveRecord.Adapters.Pg._sql_syntax = 'postgresql'

--- Loads the 'pg' binary module.
function ActiveRecord.Adapters.Pg:init()
  require 'pg'
end

--- Checks whether the adapter talks to a PostgreSQL database.
-- @return [Boolean always true]
function ActiveRecord.Adapters.Pg:is_postgres()
  return true
end

--- Connects to a PostgreSQL server through the 'pg' module and sets the connection
-- encoding. Calls #on_connection_failed if the connection fails.
-- @param config [Map database settings: host, user, password, database, port (5432 if
--   omitted) and encoding ('UTF8' if omitted)]
-- @param on_connected=nil [Function called with the adapter once the connection is ready]
function ActiveRecord.Adapters.Pg:connect(config, on_connected)
  local host, user, password, port, database = config.host, config.user, config.password, config.port, config.database

  if !port then
    port = 5432
  end

  if host == 'localhost' then
    host = '127.0.0.1'
  end

  if pg then
    self.connection = pg.new_connection()

    local success, err = self.connection:connect(host, user, password, database, port)

    if success then
      success, err = self.connection:set_encoding(config.encoding or 'UTF8')

      if !success then
        ErrorNoHalt('ActiveRecord - Failed to set connection encoding:\n')
        error_with_traceback(err)
      end

      if isfunction(on_connected) then on_connected(self) end
    else
      self:on_connection_failed(err)
    end
  else
    ErrorNoHalt(
      'ActiveRecord - PostgreSQL (pg) is not found!\nPlease make sure you have gmsv_pg in your lua/bin folder!\n'
    )
  end
end

--- Closes the PostgreSQL connection, if there is one.
function ActiveRecord.Adapters.Pg:disconnect()
  if self.connection then
    self.connection:disconnect()
  end

  self.connection = nil
end

--- Escapes a string using the PostgreSQL connection. Requires an established connection.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Pg:escape(str)
  return self.connection:escape(str)
end

--- Turns a string into an escaped SQL string literal using the PostgreSQL connection.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Pg:quote(str)
  return self.connection:quote(str)
end

--- Quotes an identifier such as a table or column name using the PostgreSQL connection.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Pg:quote_name(str)
  return self.connection:quote_name(str)
end

--- Returns the placeholder of a bind parameter, which is numbered in PostgreSQL.
-- @param index [Number position of the parameter in the list of bindings, starting at 1]
-- @return [String '$1', '$2' and so on]
function ActiveRecord.Adapters.Pg:placeholder(index)
  return '$'..index
end

--- Runs a raw SQL query on the PostgreSQL server. In sync mode this blocks until the
-- query is done; without a connection the query is put into the queue instead.
-- @param query [String SQL to run]
-- @param callback=nil [Function called with the result rows (a List of row Maps), the
--   query string and the time the query took in seconds]
-- @param query_type=nil [String unused]
-- @param bindings=nil [List values of $1, $2 and so on in the query. A query that is
--   given bindings has to be a single statement]
-- @return [Any whatever the callback returns in sync mode, nothing otherwise]
function ActiveRecord.Adapters.Pg:raw_query(query, callback, query_type, bindings)
  if !self.connection then
    return self:queue(query, callback, query_type, bindings)
  end

  bindings = bindings or {}

  local query_obj = self.connection:query(query)
  local query_start = os.clock()
  local success_func = function(result, size)
    if callback then
      for k, v in pairs(result) do
        if isstring(v) then
          result[k] = self.connection:unescape(v)
        end
      end

      local status, a, b, c, d = pcall(callback, result, query, math.Round(os.clock() - query_start, 3))

      if !status then
        ErrorNoHalt('ActiveRecord - PostgreSQL Callback Error!\n')
        error_with_traceback(a)
      end

      return a, b, c, d
    end
  end

  query_obj:on('success', success_func)
  query_obj:on('error', function(error_text)
    ErrorNoHalt('ActiveRecord - PostgreSQL Query Error!\n')
    long_error('Query: '..query..'\n')
    error_with_traceback(error_text)
  end)

  if self._sync then
    query_obj:set_sync(true)

    local success, res, size = query_obj:run(unpack(bindings))

    if success then
      return success_func(res, size)
    else
      ErrorNoHalt('ActiveRecord - PostgreSQL Query Error!\n')
      long_error('Query: '..query..'\n')
      error_with_traceback(tostring(res))
    end
  else
    query_obj:set_sync(false)
    query_obj:run(unpack(bindings))
  end
end

--- Makes the column the primary key of the table when a 'primary_key' column is created.
-- @param query [ActiveRecord::Query query the column was added to]
-- @param column [String column name]
-- @param args [Map unused]
-- @param obj [ActiveRecord::Query unused]
-- @param type [String abstract column type]
-- @param def [String unused]
function ActiveRecord.Adapters.Pg:create_column(query, column, args, obj, type, def)
  if type == 'primary_key' then
    query:set_primary_key(column)
  end
end

--- Appends 'RETURNING id' to insert queries, so that the id of the new row is passed
-- to the query callback.
-- @param query [ActiveRecord::Query unused]
-- @param query_string [String generated SQL]
-- @param query_type [String lowercase query type]
-- @return [String the extended SQL for 'insert' queries, nil for other query types]
function ActiveRecord.Adapters.Pg:append_query_string(query, query_string, query_type)
  if query_type == 'insert' then
    return query_string..' RETURNING id'
  end
end
