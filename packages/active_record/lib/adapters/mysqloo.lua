--- Adapter for MySQL servers, built on the MySQLOO binary module (`gmsv_mysqloo`). It is
-- used when the database settings name the 'mysqloo' or 'mysql' adapter. Queries run
-- asynchronously unless the adapter is in sync mode, and queries with bind parameters are
-- sent as prepared statements. Tables are created with the InnoDB engine and the encoding
-- of the database settings ('utf8' by default), and the connection is pinged every 30
-- seconds to keep it alive. Unlike the other adapters, it does not run migrations in a
-- transaction.

class 'ActiveRecord::Adapters::Mysqloo' extends 'ActiveRecord::Adapters::Abstract'

ActiveRecord.Adapters.Mysqloo.types = {
  primary_key = 'bigint(20) NOT NULL AUTO_INCREMENT',
  string = 'varchar(255)',
  text = 'text',
  integer = 'bigint(20)',
  float = 'float',
  decimal = 'decimal',
  datetime = 'datetime',
  timestamp = 'datetime',
  time = 'time',
  date = 'date',
  binary = 'blob',
  boolean = 'tinyint(1)',
  json = 'text'
}

ActiveRecord.Adapters.Mysqloo._sql_syntax = 'mysql'

--- Loads the 'mysqloo' binary module.
function ActiveRecord.Adapters.Mysqloo:init()
  require('mysqloo')
end

--- Checks whether the adapter talks to a MySQL database.
-- @return [Boolean always true]
function ActiveRecord.Adapters.Mysqloo:is_mysql()
  return true
end

--- Connects to a MySQL server through MySQLOO and pings it every 30 seconds to keep
-- the connection alive. Calls #on_connection_failed if the connection fails.
-- @param config [Map database settings: host, user, password, database, port (3306 if
--   omitted), socket and flags]
-- @param on_connected=nil [Function called with the adapter once the connection is ready]
function ActiveRecord.Adapters.Mysqloo:connect(config, on_connected)
  local host, user, password, port, database, socket, flags =
    config.host, config.user, config.password, config.port, config.database, config.socket, config.flags

  if !port then
    port = 3306
  end

  if host == 'localhost' then
    host = '127.0.0.1'
  end

  if mysqloo then
    local client_flag = flags or 0

    if !isstring(socket) then
      self.connection = mysqloo.connect(host, user, password, database, port)
    else
      self.connection = mysqloo.connect(host, user, password, database, port, socket, client_flag)
    end

    self.connection.onConnected = function(database)
      local success, error_message = database:setCharacterSet(ActiveRecord.db_settings.encoding or 'utf8')

      if !success then
        ErrorNoHalt('ActiveRecord - Failed to set MySQL encoding to UTF-8!\n')
        error_with_traceback(error_message)
      end

      if isfunction(on_connected) then on_connected(self) end
    end

    self.connection.onConnectionFailed = function(database, error_text)
      self:on_connection_failed(error_text)
    end

    self.connection:connect()

    -- ping it every 30 seconds to make sure we're not losing connection
    timer.Create('Mysqloo#keep_alive', 30, 0, function()
      self.connection:ping()
    end)
  else
    ErrorNoHalt(
      'ActiveRecord - MySQLOO is not found!\nPlease make sure you have gmsv_mysqloo in your lua/bin folder!\n'
    )
  end
end

--- Closes the MySQL connection, if there is one.
function ActiveRecord.Adapters.Mysqloo:disconnect()
  if self.connection then
    self.connection:disconnect(true)
  end

  self.connection = nil
end

--- Escapes a string using the MySQL connection. Requires an established connection.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Mysqloo:escape(str)
  return self.connection:escape(str)
end

--- Quotes an identifier such as a table or column name with backticks.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Mysqloo:quote_name(str)
  return '`'..str..'`'
end

--- Runs a raw SQL query on the MySQL server. In sync mode this blocks until the query
-- is done; without a connection the query is put into the queue instead.
-- A query that is given bindings is run as a prepared statement.
-- @param query [String SQL to run]
-- @param callback=nil [Function called with the result rows (a List of row Maps), the
--   query string and the time the query took in seconds. For 'insert' queries the
--   result is a single row with the id of the new row instead]
-- @param query_type=nil [String lowercase query type, e.g. 'insert']
-- @param bindings=nil [List values of the ? placeholders in the query. A query that is
--   given bindings has to be a single statement]
-- @return [Any whatever the callback returns in sync mode, nothing otherwise]
function ActiveRecord.Adapters.Mysqloo:raw_query(query, callback, query_type, bindings)
  if !self.connection then
    return self:queue(query, callback, query_type, bindings)
  end

  local query_obj = nil

  if bindings and #bindings > 0 then
    -- Prepared statements take a single statement, without the semicolon that ends it.
    query_obj = self.connection:prepare((query:gsub(';%s*$', '')))

    for k, v in ipairs(bindings) do
      if isnumber(v) then
        query_obj:setNumber(k, v)
      elseif isbool(v) then
        query_obj:setBoolean(k, v)
      else
        query_obj:setString(k, tostring(v))
      end
    end
  else
    query_obj = self.connection:query(query)
  end

  local query_start = os.clock()
  local success_func = function(query_obj, result)
    if callback then
      if query_type == 'insert' then
        result = { { id = query_obj:lastInsert() } }
      end

      for k, v in pairs(result) do
        if isstring(v) then
          result[k] = self:unescape(v)
        end
      end

      local status, a, b, c, d = pcall(callback, result, query, math.Round(os.clock() - query_start, 3))

      if !status then
        ErrorNoHalt('ActiveRecord - MySQL Callback Error!\n')
        error_with_traceback(a)
      end

      return a, b, c, d
    end
  end

  query_obj.onSuccess = success_func
  query_obj.onError = function(query_obj, error_text)
    self:query_failed(query, error_text, false)
  end

  if self._sync then
    local error_text = nil

    -- The callbacks run inside of wait(), so the success callback is called by hand
    -- below instead and the error is reported once the query is done.
    query_obj.onSuccess = nil
    query_obj.onError = function(query_obj, text)
      error_text = text
    end

    query_obj:start()
    query_obj:wait(true)

    if error_text then
      return self:query_failed(query, error_text)
    end

    local data = query_obj:getData()

    if data then
      return success_func(query_obj, data)
    end
  else
    query_obj:start()
  end
end

--- Sets the table options (InnoDB engine and default charset) on a query before its
-- SQL is built.
-- @param query [ActiveRecord::Query]
-- @param query_type [String unused]
-- @param queue=nil [Boolean unused]
function ActiveRecord.Adapters.Mysqloo:append_query(query, query_type, queue)
  query.options = 'ENGINE=InnoDB DEFAULT CHARSET='..(ActiveRecord.db_settings.encoding or 'utf8')
end

--- Makes the column the primary key of the table when a 'primary_key' column is created.
-- @param query [ActiveRecord::Query query the column was added to]
-- @param column [String column name]
-- @param args [Map unused]
-- @param obj [ActiveRecord::Query unused]
-- @param type [String abstract column type]
-- @param def [String unused]
function ActiveRecord.Adapters.Mysqloo:create_column(query, column, args, obj, type, def)
  if type == 'primary_key' then
    query:set_primary_key(column)
  end
end
