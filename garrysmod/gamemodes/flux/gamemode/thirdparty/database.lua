--[[
  mysql - 2.0.0
  A simple Database wrapper for Garry's Mod.

  Alexander Grist-Hucker
  http://www.alexgrist.com

  Mr. Meow
  https://mrmeow.me
--]]
--[[
  Version 2.0.0 notes:
  * Changed convention to resemble Ruby on Rails
  * Added helper functions, such as 'create_table'
  * Added abstraction layer for database types
  * Fixed a few issues and errors
  * Multi-connection support (mysqloo only)
  * Dropped support for tmysql4

  Todo:
  * Abstract adapter classes
--]]

local Database = {}
Database.connections = Database.connections or {}

local queue_table = {}
local is_connected = false
Database.module = Database.module or 'sqlite'

local function generate_create_func(obj, type, def)
  obj[type] = function(s, name, ...)
    local args = {...}
    if istable(name) then
      args = name
      name = args[1]
      table.remove(args, 1)
    end
    s.def = def
    if s.handle_create_args then
      s:handle_create_args(args)
    end
    s:create(name, s.def)
    if k == 'primary_key' then
      s:set_primary_key(name)
    end
  end
end

local function generate_create_funcs(obj, tab)
  for k, v in pairs(tab) do
    generate_create_func(obj, k, v)
  end
end

--[[
  Define database-specific column data types
--]]
local mysql_types = {
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

local sqlite_types = {
  primary_key = 'integer AUTOINCREMENT NOT NULL',
  string = 'varchar',
  text = 'text',
  integer = 'integer',
  float = 'float',
  decimal = 'decimal',
  datetime = 'datetime',
  timestamp = 'timestamp',
  time = 'time',
  date = 'date',
  binary = 'blob',
  boolean = 'boolean',
  json = 'json'
}

local queries_with_create = {
  create = true, change = true
}

--[[
  Begin Query Class.
--]]

local DatabaseQuery = {}
DatabaseQuery.__index = DatabaseQuery

function DatabaseQuery.new(table_name, query_type)
  local new_obj = setmetatable({}, DatabaseQuery)
    new_obj.query_type = query_type
    new_obj.table_name = table_name
    new_obj.select_list = {}
    new_obj.insert_list = {}
    new_obj.update_list = {}
    new_obj.create_list = {}
    new_obj.where_list = {}
    new_obj.order_list = {}
    new_obj.remove_column_list = {}
    new_obj.rename_list = {}

    if queries_with_create[query_type:lower()] then
      generate_create_funcs(new_obj, Database.module != 'sqlite' and mysql_types or sqlite_types)
    end
  return new_obj
end

function DatabaseQuery:handle_create_args(args)
  if args['null'] == false then
    self.def = self.def..' NOT NULL'
  elseif args['null'] == true then
    self.def = self.def..' DEFAULT NULL'
  end

  if args['default'] and args['null'] != true then
    self.def = self.def..' DEFAULT '..args['default']
  end
end

function DatabaseQuery:escape(text)
  return Database:escape(tostring(text))
end

function DatabaseQuery:for_table(table_name)
  self.table_name = table_name
end

function DatabaseQuery:where(key, value)
  self:where_equal(key, value)
end

function DatabaseQuery:where_equal(key, value)
  table.insert(self.where_list, '`'..key..'` = \''..self:escape(value)..'\'')
end

function DatabaseQuery:where_not_equal(key, value)
  table.insert(self.where_list, '`'..key..'` != \''..self:escape(value)..'\'')
end

function DatabaseQuery:where_like(key, value)
  table.insert(self.where_list, '`'..key..'` LIKE \''..self:escape(value)..'\'')
end

function DatabaseQuery:where_not_like(key, value)
  table.insert(self.where_list, '`'..key..'` NOT LIKE \''..self:escape(value)..'\'')
end

function DatabaseQuery:where_gt(key, value)
  table.insert(self.where_list, '`'..key..'` > \''..self:escape(value)..'\'')
end

function DatabaseQuery:where_lt(key, value)
  table.insert(self.where_list, '`'..key..'` < \''..self:escape(value)..'\'')
end

function DatabaseQuery:where_gte(key, value)
  table.insert(self.where_list, '`'..key..'` >= \''..self:escape(value)..'\'')
end

function DatabaseQuery:where_lte(key, value)
  table.insert(self.where_list, '`'..key..'` <= \''..self:escape(value)..'\'')
end

function DatabaseQuery:order(key)
  if isstring(key) then
    table.insert(self.order_list, '`'..key..'` DESC')
  elseif istable(key) then
    if key['asc'] then
      table.insert(self.order_list, '`'..key['asc']..'` ASC')
    elseif key['desc'] then
      table.insert(self.order_list, '`'..key['desc']..'` DESC')
    end
  end
end

function DatabaseQuery:callback(callback)
  self._callback = callback
end

function DatabaseQuery:select(field_name)
  table.insert(self.select_list, '`'..field_name..'`')
end

function DatabaseQuery:remove(field_name)
  table.insert(self.remove_column_list, '`'..field_name..'`')
end

function DatabaseQuery:rename(what, into)
  table.insert(self.rename_list, {'`'..what..'`', '`'..into..'`'})
end

function DatabaseQuery:insert(key, value)
  table.insert(self.insert_list, {'`'..key..'`', '\''..self:escape(value)..'\''})
end

function DatabaseQuery:update(key, value)
  table.insert(self.update_list, {'`'..key..'`', '\''..self:escape(value)..'\''})
end

function DatabaseQuery:create(key, value)
  table.insert(self.create_list, {'`'..key..'`', value})
end

function DatabaseQuery:set_primary_key(key)
  self.prim_key = '`'..key..'`'
end

function DatabaseQuery:limit(value)
  self.limit = value
end

function DatabaseQuery:offset(value)
  self.offset = value
end

local function build_select_query(query_obj)
  local query_string = {'SELECT'}

  if (!istable(query_obj.select_list) or #query_obj.select_list == 0) then
    table.insert(query_string, ' *')
  else
    table.insert(query_string, ' '..table.concat(query_obj.select_list, ', '))
  end

  if (isstring(query_obj.table_name)) then
    table.insert(query_string, ' FROM `'..query_obj.table_name..'` ')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  if (istable(query_obj.where_list) and #query_obj.where_list > 0) then
    table.insert(query_string, ' WHERE ')
    table.insert(query_string, table.concat(query_obj.where_list, ' AND '))
  end

  if (istable(query_obj.order_list) and #query_obj.order_list > 0) then
    table.insert(query_string, ' ORDER BY ')
    table.insert(query_string, table.concat(query_obj.order_list, ', '))
  end

  if (isnumber(query_obj.limit)) then
    table.insert(query_string, ' LIMIT ')
    table.insert(query_string, query_obj.limit)
  end

  return table.concat(query_string)
end

local function build_insert_query(query_obj)
  local query_string = {'INSERT INTO'}
  local key_list = {}
  local value_list = {}

  if (isstring(query_obj.table_name)) then
    table.insert(query_string, ' `'..query_obj.table_name..'`')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  for k, v in ipairs(query_obj.insert_list) do
    table.insert(key_list, v[1])
    table.insert(value_list, v[2])
  end

  if (#key_list == 0) then
    return
  end

  table.insert(query_string, ' ('..table.concat(key_list, ', ')..')')
  table.insert(query_string, ' VALUES ('..table.concat(value_list, ', ')..')')

  return table.concat(query_string)
end

local function build_update_query(query_obj)
  local query_string = {'UPDATE'}

  if (isstring(query_obj.table_name)) then
    table.insert(query_string, ' `'..query_obj.table_name..'`')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  if (istable(query_obj.update_list) and #query_obj.update_list > 0) then
    local update_list = {}

    table.insert(query_string, ' SET')

    for k, v in ipairs(query_obj.update_list) do
      table.insert(update_list, v[1]..' = '..v[2])
    end

    table.insert(query_string, ' '..table.concat(update_list, ', '))
  end

  if (istable(query_obj.where_list) and #query_obj.where_list > 0) then
    table.insert(query_string, ' WHERE ')
    table.insert(query_string, table.concat(query_obj.where_list, ' AND '))
  end

  if (isnumber(query_obj.offset)) then
    table.insert(query_string, ' OFFSET ')
    table.insert(query_string, query_obj.offset)
  end

  return table.concat(query_string)
end

local function build_delete_query(query_obj)
  local query_string = {'DELETE FROM'}

  if (isstring(query_obj.table_name)) then
    table.insert(query_string, ' `'..query_obj.table_name..'`')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  if (istable(query_obj.where_list) and #query_obj.where_list > 0) then
    table.insert(query_string, ' WHERE ')
    table.insert(query_string, table.concat(query_obj.where_list, ' AND '))
  end

  if (isnumber(query_obj.limit)) then
    table.insert(query_string, ' LIMIT ')
    table.insert(query_string, query_obj.limit)
  end

  return table.concat(query_string)
end

local function build_drop_query(query_obj)
  local query_string = {'DROP TABLE'}

  if (isstring(query_obj.table_name)) then
    table.insert(query_string, ' `'..query_obj.table_name..'`')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  return table.concat(query_string)
end

local function build_truncate_query(query_obj)
  local query_string = {'TRUNCATE TABLE'}

  if (isstring(query_obj.table_name)) then
    table.insert(query_string, ' `'..query_obj.table_name..'`')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  return table.concat(query_string)
end

local function build_create_query(query_obj)
  local query_string = {'CREATE TABLE IF NOT EXISTS'}

  if (isstring(query_obj.table_name)) then
    table.insert(query_string, ' `'..query_obj.table_name..'`')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  table.insert(query_string, ' (')

  if (istable(query_obj.create_list) and #query_obj.create_list > 0) then
    local create_list = {}

    for k, v in ipairs(query_obj.create_list) do
      if (Database.module == 'sqlite') then
        table.insert(create_list, v[1]..' '..string.gsub(string.gsub(string.gsub(v[2], 'AUTO_INCREMENT', ''), 'AUTOINCREMENT', ''), 'INT ', 'INTEGER '))
      else
        table.insert(create_list, v[1]..' '..v[2])
      end
    end

    table.insert(query_string, ' '..table.concat(create_list, ', '))
  end

  if (isstring(query_obj.prim_key)) then
    table.insert(query_string, ', PRIMARY KEY')
    table.insert(query_string, ' ('..query_obj.prim_key..')')
  end

  table.insert(query_string, ' )')

  return table.concat(query_string)
end

local function build_change_query(query)
  local query_string = {'ALTER TABLE'}

  if (isstring(query.table_name)) then
    table.insert(query_string, ' `'..query.table_name..'`')
  else
    ErrorNoHalt('[Database] No table name specified!\n')
    return
  end

  if #query.create_list > 0 then
    for k, v in ipairs(query.create_list) do
      table.insert(query_string, ' ADD '..v[1]..' '..v[2]..',')
    end
  end

  if #query.remove_column_list > 0 then
    for k, v in ipairs(query.remove_column_list) do
      table.insert(query_string, ' DROP '..v..',')
    end
  end

  if #query.rename_list > 0 then
    for k, v in ipairs(query.rename_list) do
      table.insert(query_string, ' RENAME '..v[1]..' TO '..v[2]..',')
    end
  end

  return table.concat(query_string):Trim():Trim(',')
end

function DatabaseQuery:execute(queue_query)
  local query_string = nil
  local query_type = string.lower(self.query_type)

  if (query_type == 'select') then
    query_string = build_select_query(self)
  elseif (query_type == 'insert') then
    query_string = build_insert_query(self)
  elseif (query_type == 'update') then
    query_string = build_update_query(self)
  elseif (query_type == 'delete') then
    query_string = build_delete_query(self)
  elseif (query_type == 'drop') then
    query_string = build_drop_query(self)
  elseif (query_type == 'truncate') then
    query_string = build_truncate_query(self)
  elseif (query_type == 'create') then
    query_string = build_create_query(self)
  elseif (query_type == 'change') then
    query_string = build_change_query(self)
  end

  if (isstring(query_string)) then
    if (!queue_query) then
      return Database:raw_query(query_string, self._callback)
    else
      return Database:queue(query_string, self._callback)
    end
  end
end

--[[
  End Query Class.
--]]

function Database:select(table_name)
  return DatabaseQuery.new(table_name, 'SELECT')
end

function Database:insert(table_name)
  return DatabaseQuery.new(table_name, 'INSERT')
end

function Database:update(table_name)
  return DatabaseQuery.new(table_name, 'UPDATE')
end

function Database:delete(table_name)
  return DatabaseQuery.new(table_name, 'DELETE')
end

function Database:drop(table_name)
  return DatabaseQuery.new(table_name, 'DROP')
end

function Database:truncate(table_name)
  return DatabaseQuery.new(table_name, 'TRUNCATE')
end

function Database:create(table_name)
  return DatabaseQuery.new(table_name, 'CREATE')
end

function Database:change(table_name)
  return DatabaseQuery.new(table_name, 'CHANGE')
end

function Database:set_current_connection(id)
  if (self.module != 'mysqloo') then
    id = 'main'
  end

  if (self.connections[id]) then
    self.connection = self.connections[id]
    self.current_connection_id = id
  else
    self.connection = self.connections['main']
    self.current_connection_id = 'main'
  end
end

-- A function to connect to the MySQL Database.
function Database:connect(host, username, password, database, port, socket, flags, id)
  if (!port) then
    port = 3306
  end

  if (!id) then
    id = self.current_connection_id or 'main'
  else
    print('[Database] Creating multi-connection with ID: '..id)
  end

  if (self.module != 'sqlite') then
    require(self.module)
  else
    self:on_connected()
    return
  end

  if (self.module == 'mysqloo') then
    if (!istable(mysqloo)) then
      require('mysqloo')
    end

    if (mysqloo) then
      local client_flag = flags or 0

      if (!isstring(socket)) then
        self.connections[id] = mysqloo.connect(host, username, password, database, port)
      else
        self.connections[id] = mysqloo.connect(host, username, password, database, port, socket, client_flag)
      end

      self.connections[id].onConnected = function(database)
        self:on_connected()
      end

      self.connections[id].onConnectionFailed = function(database, error_text)
        self:on_connection_failed(error_text)
      end    

      self.connections[id]:connect()
    else
      ErrorNoHalt(string.format('[Database] The %s module does not exist!\n', self.module))
    end
  end

  self:set_current_connection(id)
end

-- A function to query the MySQL Database.
function Database:raw_query(query, callback, flags, ...)
  if (!self.connection and self.module != 'sqlite') then
    self:queue(query)
  end

  if (self.module == 'mysqloo') then
    local query_obj = self.connection:query(query)

    query_obj:setOption(mysqloo.OPTION_NAMED_FIELDS)
    query_obj.onSuccess = function(query_obj, result)
      if (callback) then
        for k, v in pairs(result) do
          if isstring(v) then
            result[k] = Database:unescape(v)
          end
        end

        local status, value = pcall(callback, result)

        if (!status) then
          ErrorNoHalt(string.format('[Database] MySQL Callback Error!\n%s\n', value))
        end
      end
    end
    query_obj.onError = function(query_obj, error_text)
      ErrorNoHalt('[Database] MySQL Query Error!\n')
      ErrorNoHalt('Query: '..query..'\n')
      ErrorNoHalt(error_text..'\n')
    end
    query_obj:start()
  elseif (Database.module == 'sqlite') then
    local result = sql.Query(query)

    if (result == false) then
      ErrorNoHalt('[Database] SQLite Query Error!\n')
      ErrorNoHalt('Query: '..query..'\n')
      ErrorNoHalt(sql.LastError()..'\n')
    else
      if (callback) then
        local status, value = pcall(callback, result)

        if (!status) then
          ErrorNoHalt(string.format('[Database] SQL callback Error!\n%s\n', value))
        end
      end
    end
  else
    ErrorNoHalt(string.format('[Database] Unsupported module \'%s\'!\n', Database.module))
  end
end

-- A function to add a query to the queue.
function Database:queue(query_string, callback)
  if (isstring(query_string)) then
    table.insert(queue_table, {query_string, callback})
  end
end

-- A function to escape a string for MySQL.
function Database:escape(text)
  if (self.connection) then
    if (Database.module == 'mysqloo') then
      return self.connection:escape(text)
    end
  else
    return sql.SQLStr(string.gsub(text, '"', '\''):gsub('\'', '\'\''), true)
  end
end

function Database:unescape(text)
  if Database.module == 'sqlite' then
    return text:gsub('\'\'', '\'')
  else
    return text
  end
end

-- A function to disconnect from the MySQL Database.
function Database:disconnect(id)
  is_connected = false
end

function Database:think()
  if (#queue_table > 0) then
    if (istable(queue_table[1])) then
      local queue_obj = queue_table[1]
      local query_string = queue_obj[1]
      local callback = queue_obj[2]

      if (isstring(query_string)) then
        self:raw_query(query_string, callback)
      end

      table.remove(queue_table, 1)
    end
  end
end

-- A function to set the module that should be used.
function Database:set_module(mod_name)
  Database.module = mod_name

  if (mod_name != 'sqlite') then
    print('Using '..mod_name..' as database module...')

    if safe_require then
      safe_require(mod_name)
    else
      require(mod_name)
    end
  end
end

function Database:is_result(result)
  return (istable(result) and #result > 0)
end

-- Called when the Database connects sucessfully.
function Database:on_connected()
  is_connected = true

  MsgC(Color(25, 235, 25), '[Database] Connected to the Database using '..Database.module..'!\n')
  hook.Run('database_connected')
end

-- Called when the Database connection fails.
function Database:on_connection_failed(error_text)
  ErrorNoHalt('[Database] Unable to connect to the Database!\n'..error_text..'\n')
  hook.Run('database_connection_failed', error_text)
end

-- A function to check whether or not the module is connected to a Database.
function Database:is_connected()
  return is_connected
end

function Database:easy_write(table_name, where, data)
  if (!data or !istable(data)) then
    ErrorNoHalt('[Database] Easy write error! Data has unexpected value type (table expected, got '..type(data)..')\n')
    return
  end

  if (!where) then
    ErrorNoHalt('[Database] Easy write error! \'where\' table is malformed! ([1] = '..type(where[1])..', [2] = '..type(where[2])..')\n')
    return
  end

  local query = self:select(table_name)
    if (istable(where[1])) then
      for k, v in pairs(where) do
        query:where(v[1], v[2])
      end
    else
      query:where(where[1], where[2])
    end

    query:callback(function(result, status, lastID)
      if (istable(result) and #result > 0) then
        local update_obj = self:update(table_name)
          for k, v in pairs(data) do
            update_obj:update(k, v)
          end

          update_obj:where(where[1], where[2])
        update_obj:execute()
      else
        local insert_obj = self:insert(table_name)
          for k, v in pairs(data) do
            insert_obj:insert(k, v)
          end
        insert_obj:execute()
      end
    end)
  query:execute()
end

function Database:easy_read(table_name, where, callback)
  if (!where) then
    ErrorNoHalt('[Database] Easy MySQL Read error! \'where\' table is malformed! ([1] = '..type(where[1])..', [2] = '..type(where[2])..')\n')
    return false
  end

  local query = self:select(table_name)
    if (istable(where[1])) then
      for k, v in pairs(where) do
        query:where(v[1], v[2])
      end
    else
      query:where(where[1], where[2])
    end

    query:callback(function(result)
      local success, value = pcall(callback, result, (istable(result) and #result > 0))

      if (!success) then
        ErrorNoHalt('[Easy Read Error] '..value..'\n')
      end
    end)
  query:execute()
end

timer.Create('Database#think', 1, 0, function()
  Database:think()
end)

function create_table(name, callback)
  local query = Database:create(name)
    callback(query)
  query:execute()
end

function drop_table(name)
  return Database:drop(name):execute()
end

function change_table(name, callback)
  local query = Database:change(name)
    callback(query)
  query:execute()
end

function add_index(args)
  if !isstring(args[1]) or !args[2] then return end

  local cols = istable(args[2]) and args[2] or {args[2]}
  local len = args['length']

  local query = 'CREATE '..(args['unique'] == true and 'UNIQUE' or '')..'INDEX '..
  (args['name'] or args[1]..'_'..table.concat(cols, '_')..'_index')

  if args['using'] then
    query = query..' USING '..args['using']
  end

  query = query..' ON '..args[1]..'('

  for k, v in ipairs(cols) do
    query = query..'`'..v..'`'

    if len and Database.module != 'sqlite' then
      query = query..'('..(istable(len) and len[v] or len)..')'
    end

    if k != #cols then
      query = query..', '
    end
  end

  query = query..')'

  if args['where'] then
    query = query..' WHERE '..args['where']
  end

  query = query..';'

  Database:raw_query(query)
end

return Database
