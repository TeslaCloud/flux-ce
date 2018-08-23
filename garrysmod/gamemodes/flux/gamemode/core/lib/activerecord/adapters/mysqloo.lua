class('Mysqloo', ActireRecord.Adapters.Abstract, ActiveRecord.Adapters)

ActiveRecord.Adapters.Mysqloo.types = {
  primary_key = 'bigint auto_increment',
  string = 'varchar(255)',
  text = 'text(65535)',
  integer = 'int(4)',
  float = 'float(24)',
  decimal = 'decimal',
  datetime = 'datetime',
  timestamp = 'timestamp',
  time = 'time',
  date = 'date',
  binary = 'blob(65535)',
  boolean = 'tinyint(1)',
  json = 'json'
}

function ActiveRecord.Adapters.Mysqloo:init()
  require('mysqloo')
end

function ActiveRecord.Adapters.Mysqloo:connect(config)
  local host, user, password, port, database, socket, flags = config.host, config.user, config.password, config.port, config.database, config.socket, config.flags

  if (!port) then
    port = 3306
  end

  if (mysqloo) then
    local client_flag = flags or 0

    if (!isstring(socket)) then
      self.connection = mysqloo.connect(host, user, password, database, port)
    else
      self.connection = mysqloo.connect(host, user, password, database, port, socket, client_flag)
    end

    self.connection.onConnected = function(database)
      local success, error_message = database:setCharacterSet(ActiveRecord.db_settings.encoding or 'utf8')

      if !success then
        ErrorNoHalt('ActiveRecord - Failed to set MySQL encoding to UTF-8!\n')
        ErrorNoHalt(error_message..'\n')
      end
      self:on_connected()
    end

    self.connection.onConnectionFailed = function(database, error_text)
      self:on_connection_failed(error_text)
    end    

    self.connection:connect()
  else
    ErrorNoHalt(string.format('ActiveRecord - MySQLOO is not found!\nPlease make sure you have gmsv_mysqloo in your lua/bin folder!\n'))
  end
end

function ActiveRecord.Adapters.Mysqloo:disconnect()
  if self.connection then
    self.connection:disconnect(true)
  end
  self.connection = nil
end

function ActiveRecord.Adapters.Mysqloo:escape(str)
  return self.connection:escape(str)
end

function ActiveRecord.Adapters.Mysqloo:raw_query(query, callback, flags, ...)
  if (!self.connection and self.module != 'sqlite') then
    return self:queue(query)
  end

  local query_obj = self.connection:query(query)

  query_obj:setOption(mysqloo.OPTION_NAMED_FIELDS)
  query_obj.onSuccess = function(query_obj, result)
    if (callback) then
      for k, v in pairs(result) do
        if isstring(v) then
          result[k] = self:unescape(v)
        end
      end

      local status, value = pcall(callback, result)

      if (!status) then
        ErrorNoHalt(string.format('ActiveRecord - MySQL Callback Error!\n%s\n', value))
      end
    end
  end
  query_obj.onError = function(query_obj, error_text)
    ErrorNoHalt('ActiveRecord - MySQL Query Error!\n')
    ErrorNoHalt('Query: '..query..'\n')
    ErrorNoHalt(error_text..'\n')
  end
  query_obj:start()
end
