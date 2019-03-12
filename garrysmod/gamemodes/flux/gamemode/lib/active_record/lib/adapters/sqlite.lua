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

function ActiveRecord.Adapters.Sqlite:connect(settings, on_connected)
  if isfunction(on_connected) then on_connected(self) end
end

function ActiveRecord.Adapters.Sqlite:is_sqlite()
  return true
end

function ActiveRecord.Adapters.Sqlite:escape(str)
  return sql.SQLStr(string.gsub(str, "'", "`"), true)
end

function ActiveRecord.Adapters.Sqlite:unescape(str)
  return text:gsub("''", "'")
end

function ActiveRecord.Adapters.Sqlite:raw_query(query, callback, query_type)
  local query_start = os.clock()
  local result = sql.Query(query)

  if result == false then
    ErrorNoHalt('ActiveRecord - SQLite Query Error!\n')
    ErrorNoHalt('Query: '..query..'\n')
    ErrorNoHalt(sql.LastError()..'\n')
  else
    if callback then
      local status, a, b, c, d = pcall(callback, result, query, math.Round(os.clock() - query_start, 3))

      if !status then
        ErrorNoHalt('ActiveRecord - SQLite Callback Error!\n')
        ErrorNoHalt(a..'\n')
      end

      return a, b, c, d
    end
  end
end

function ActiveRecord.Adapters.Sqlite:append_query_string(query, query_string, query_type)
  if query_type == 'insert' then
    return query_string:ensure_end(';')..' SELECT last_insert_rowid();'
  end
end
