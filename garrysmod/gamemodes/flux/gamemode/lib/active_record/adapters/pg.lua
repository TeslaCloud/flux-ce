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

function ActiveRecord.Adapters.Pg:init()
  require 'pg'
end

function ActiveRecord.Adapters.Pg:is_postgres()
  return true
end

function ActiveRecord.Adapters.Pg:connect(config)
  local host, user, password, port, database = config.host, config.user, config.password, config.port, config.database

  if !port then
    port = 5432
  end

  if pg then
    self.connection = pg.new_connection()

    local success, err = self.connection:connect(host, user, password, database, port)

    if success then
      success, err = self.connection:set_encoding(config.encoding or 'UTF8')

      if !success then
        ErrorNoHalt('ActiveRecord - Failed to set connection encoding:\n')
        ErrorNoHalt(err)
      end

      self:on_connected()
    else
      self:on_connection_failed(err)
    end
  else
    ErrorNoHalt('ActiveRecord - PostgreSQL (pg) is not found!\nPlease make sure you have gmsv_pg in your lua/bin folder!\n')
  end
end

function ActiveRecord.Adapters.Pg:disconnect()
  if self.connection then
    self.connection:disconnect()
  end
  self.connection = nil
end

function ActiveRecord.Adapters.Pg:escape(str)
  return self.connection:escape(str)
end

function ActiveRecord.Adapters.Pg:quote(str)
  return self.connection:quote(str)
end

function ActiveRecord.Adapters.Pg:quote_name(str)
  return self.connection:quote_name(str)
end

function ActiveRecord.Adapters.Pg:raw_query(query, callback, flags, ...)
  if !self.connection then
    return self:queue(query)
  end

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
        ErrorNoHalt(a..'\n')
      end

      return a, b, c, d
    end
  end

  query_obj:on("success", success_func)
  query_obj:on("error", function(error_text)
    ErrorNoHalt('ActiveRecord - PostgreSQL Query Error!\n')
    ErrorNoHalt('Query: '..query..'\n')
    ErrorNoHalt(error_text..'\n')
  end)

  if self._sync then
    query_obj:set_sync(true)

    local success, res, size = query_obj:run()

    if success then
      return success_func(res, size)
    else
      ErrorNoHalt('ActiveRecord - PostgreSQL Query Error!\n')
      ErrorNoHalt('Query: '..query..'\n')
      ErrorNoHalt(tostring(res)..'\n')
    end
  else
    query_obj:set_sync(false)
    query_obj:run()
  end
end

function ActiveRecord.Adapters.Pg:create_column(query, column, args, obj, type, def)
  if type == 'primary_key' then
    query:set_primary_key(column)
  end
end
