--- Adapter for MySQL and MariaDB servers, built on the MySQLOO binary module
-- (`gmsv_mysqloo`). It is used when the database settings name the 'mysqloo', 'mysql' or
-- 'mariadb' adapter. Queries run asynchronously unless the adapter is in sync mode, and
-- queries with bind parameters are sent as prepared statements. Tables are created with the
-- InnoDB engine and the encoding of the database settings (utf8mb4 for 'utf8' or none), and
-- the connection is pinged every 30 seconds to keep it alive. Unlike the other adapters, it
-- does not run migrations in a transaction.

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

--- Port that the adapter connects to when the database settings give none.
-- @return [Number]
ActiveRecord.Adapters.Mysqloo.default_port = 3306

--- Returns the character set of the connection and of the tables it creates: the encoding of the
-- database settings, where 'utf8' (or none at all) stands for utf8mb4, the full UTF-8 of
-- MySQL, rather than for its three-byte utf8 that cannot hold emoji.
-- @return [String]
local function character_set()
  local encoding = ActiveRecord.db_settings.encoding

  if !isstring(encoding) or encoding:lower() == 'utf8' or encoding:lower() == 'utf-8' then
    return 'utf8mb4'
  end

  return encoding
end

--- Name of the binary module the adapter is built on.
-- @return [String]
ActiveRecord.Adapters.Mysqloo.binary_module = 'mysqloo'

--- Loads the 'mysqloo' binary module. When it cannot be opened, #connect says how to install
-- it.
function ActiveRecord.Adapters.Mysqloo:init()
  require_module(self.binary_module)
end

--- Converts a unix timestamp to the date-time form that MySQL takes in date-time columns.
-- @param unix_time [Number]
-- @return [String e.g. '2019-03-09 12:00:00', in UTC]
function ActiveRecord.Adapters.Mysqloo:format_datetime(unix_time)
  return os.date('!%Y-%m-%d %H:%M:%S', unix_time)
end

--- Checks whether the adapter talks to a MySQL database.
-- @return [Boolean always true]
function ActiveRecord.Adapters.Mysqloo:is_mysql()
  return true
end

--- Connects to a MySQL server through MySQLOO and pings it every 30 seconds to keep
-- the connection alive. Reports a failed connection with #connection_failed.
-- @param config [Map database settings: host, user, password, database, port (3306 if
--   omitted), socket and flags]
-- @param on_connected=nil [Function called with the adapter once the connection is ready]
-- @param on_failed=nil [Function called with the adapter and the error text when the
--   connection fails, in place of #on_connection_failed]
function ActiveRecord.Adapters.Mysqloo:connect(config, on_connected, on_failed)
  local host, user, password, port, database, socket, flags =
    config.host, config.user, config.password, config.port, config.database, config.socket, config.flags

  if !port then
    port = self.default_port
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

    self.connection.onConnected = function(connection)
      local success, error_message = connection:setCharacterSet(character_set())

      if !success then
        ErrorNoHalt('ActiveRecord - Failed to set the MySQL character set to '..character_set()..'!\n')
        error_with_traceback(error_message)
      end

      if isfunction(on_connected) then on_connected(self) end
    end

    self.connection.onConnectionFailed = function(_database, error_text)
      self:connection_failed(error_text, on_failed)
    end

    self.connection:connect()

    timer.Create('Mysqloo#keep_alive', 30, 0, function()
      if self.connection then
        self.connection:ping()
      end
    end)
  else
    ErrorNoHalt(
      'ActiveRecord - MySQLOO is not found!\nIt is not an fpkg package yet: copy gmsv_mysqloo to your '..
      'lua/bin folder by hand!\n'
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

--- Quotes an identifier such as a table or column name with backticks, doubling the
-- backticks in it.
-- @param str [String]
-- @return [String]
function ActiveRecord.Adapters.Mysqloo:quote_name(str)
  return '`'..string.gsub(str, '`', '``')..'`'
end

--- Runs a raw SQL query on the MySQL server. In sync mode this blocks until the query
-- is done; without a connection the query is put into the queue instead.
-- A query that is given bindings is run as a prepared statement.
-- @param query [String SQL to run]
-- @param callback=nil [Function called with the result rows (a List of row Maps), the
--   query string, the time the query took in seconds and the bindings. For 'insert'
--   queries the result is a single row with the id of the new row instead]
-- @param query_type=nil [String lowercase query type, e.g. 'insert']
-- @param bindings=nil [List values of the ? placeholders in the query. A query that is
--   given bindings has to be a single statement]
-- @param error_callback=nil [Function called with the error text if the query fails]
-- @return [Any whatever the callback returns in sync mode, nothing otherwise]
function ActiveRecord.Adapters.Mysqloo:raw_query(query, callback, query_type, bindings, error_callback)
  if !self.connection then
    return self:queue(query, callback, query_type, bindings, error_callback)
  end

  local query_obj = nil

  if bindings and #bindings > 0 then
    query_obj = self.connection:prepare((query:gsub(';%s*$', '')))

    for index, value in ipairs(bindings) do
      if isnumber(value) then
        query_obj:setNumber(index, value)
      elseif isbool(value) then
        query_obj:setBoolean(index, value)
      else
        query_obj:setString(index, tostring(value))
      end
    end
  else
    query_obj = self.connection:query(query)
  end

  local query_start = SysTime()
  local success_func = function(completed_query, result)
    if callback then
      if query_type == 'insert' then
        result = { { id = completed_query:lastInsert() } }
      end

      return self:run_callback(callback, result, query, query_start, bindings)
    end
  end

  query_obj.onSuccess = success_func
  query_obj.onError = function(_query_obj, error_text)
    self:report_failure(query, error_text, error_callback, false)
  end

  if self._sync then
    local error_text = nil

    query_obj.onSuccess = nil
    query_obj.onError = function(_query_obj, text)
      error_text = text
    end

    query_obj:start()
    query_obj:wait(false)

    if error_text then
      return self:report_failure(query, error_text, error_callback)
    end

    local data = query_obj:getData()

    if data then
      return success_func(query_obj, data)
    end
  else
    query_obj:start()
  end
end

--- Sets the table options (InnoDB engine and default character set) on a query before its
-- SQL is built.
-- @param query [ActiveRecord::Query]
-- @param _query_type [String unused]
-- @param _queue=nil [Boolean unused]
function ActiveRecord.Adapters.Mysqloo:append_query(query, _query_type, _queue)
  query.options = 'ENGINE=InnoDB DEFAULT CHARSET='..character_set()
end

--- Makes the column the primary key of the table when a 'primary_key' column is created.
-- @param query [ActiveRecord::Query query the column was added to]
-- @param column [String column name]
-- @param _args [Map unused]
-- @param _obj [ActiveRecord::Query unused]
-- @param type [String abstract column type]
-- @param _def [String unused]
function ActiveRecord.Adapters.Mysqloo:create_column(query, column, _args, _obj, type, _def)
  if type == 'primary_key' then
    query:set_primary_key(column)
  end
end
