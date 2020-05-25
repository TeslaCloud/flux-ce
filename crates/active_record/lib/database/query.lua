--[[
  mysql - 2.0.0
  A simple Database wrapper for Garry's Mod.

  Alexander Grist-Hucker
  http://www.alexgrist.com

  Meow the Cat
  https://teslacloud.net
--]]

class 'ActiveRecord::Query'

local queries_with_create = {
  create = true, change = true
}

function ActiveRecord.Query:init(table_name, query_type)
  self.query_type = query_type
  self.table_name = table_name
  self.select_list = {}
  self.insert_list = {}
  self.update_list = {}
  self.create_list = {}
  self.where_list = {}
  self.order_list = {}
  self.remove_column_list = {}
  self.rename_list = {}

  if queries_with_create[query_type:lower()] then
    ActiveRecord.generate_create_funcs(self)
  end
end

function ActiveRecord.Query:handle_create_args(args)
  if args['null'] == false then
    self.def = self.def..' NOT NULL'
  elseif args['null'] == true then
    self.def = self.def..' DEFAULT NULL'
  end

  if args['default'] != nil and args['null'] != true then
    self.def = self.def..' DEFAULT '..tostring(args['default'])
  end
end

function ActiveRecord.Query:escape(text)
  return ActiveRecord.adapter:escape(tostring(text))
end

function ActiveRecord.Query:quote(text)
  if text == nil then
    return 'NULL'
  else
    return ActiveRecord.adapter:quote(tostring(text))
  end
end

function ActiveRecord.Query:quote_column(text)
  return ActiveRecord.adapter:quote_name(tostring(text))
end

function ActiveRecord.Query:for_table(table_name)
  self.table_name = table_name
end

function ActiveRecord.Query:where(key, value)
  self:where_equal(key, value)
end

function ActiveRecord.Query:where_raw(condition)
  table.insert(self.where_list, condition)
end

function ActiveRecord.Query:where_equal(key, value)
  table.insert(self.where_list, self:quote_column(key)..' = '..self:quote(value))
end

function ActiveRecord.Query:where_not_equal(key, value)
  table.insert(self.where_list, self:quote_column(key)..' != '..self:quote(value))
end

function ActiveRecord.Query:where_like(key, value)
  table.insert(self.where_list, self:quote_column(key)..' LIKE '..self:quote(value))
end

function ActiveRecord.Query:where_not_like(key, value)
  table.insert(self.where_list, self:quote_column(key)..' NOT LIKE '..self:quote(value))
end

function ActiveRecord.Query:where_gt(key, value)
  table.insert(self.where_list, self:quote_column(key)..' > '..self:quote(value))
end

function ActiveRecord.Query:where_lt(key, value)
  table.insert(self.where_list, self:quote_column(key)..' < '..self:quote(value))
end

function ActiveRecord.Query:where_gte(key, value)
  table.insert(self.where_list, self:quote_column(key)..' >= '..self:quote(value))
end

function ActiveRecord.Query:where_lte(key, value)
  table.insert(self.where_list, self:quote_column(key)..' <= '..self:quote(value))
end

function ActiveRecord.Query:order(key)
  if isstring(key) then
    table.insert(self.order_list, self:quote_column(key)..' DESC')
  elseif istable(key) then
    if key['asc'] then
      table.insert(self.order_list, self:quote_column(key['asc'])..' ASC')
    elseif key['desc'] then
      table.insert(self.order_list, self:quote_column(key['desc'])..' DESC')
    end
  end
end

function ActiveRecord.Query:callback(callback)
  self._callback = callback
end

function ActiveRecord.Query:select(field_name)
  table.insert(self.select_list, self:quote_column(field_name))
end

function ActiveRecord.Query:remove(field_name)
  table.insert(self.remove_column_list, self:quote_column(field_name))
end

function ActiveRecord.Query:rename(what, into)
  table.insert(self.rename_list, { self:quote_column(what), self:quote_column(into) })
end

function ActiveRecord.Query:insert(key, value)
  table.insert(self.insert_list, { key, self:quote(value) })
end

function ActiveRecord.Query:update(key, value)
  table.insert(self.update_list, { key, self:quote(value) })
end

function ActiveRecord.Query:create(key, value)
  table.insert(self.create_list, { self:quote_column(key), value })
end

function ActiveRecord.Query:set_primary_key(key)
  self.prim_key = self:quote_column(key)
end

function ActiveRecord.Query:limit(value)
  self._limit = value
end

function ActiveRecord.Query:offset(value)
  self.offset = value
end

function ActiveRecord.Query:overwrite(overwrite)
  self._overwrite = overwrite
end

local function build_select_query(query_obj)
  local query_string = { 'SELECT ' }

  if !istable(query_obj.select_list) or #query_obj.select_list == 0 then
    table.insert(query_string, ' *')
  else
    table.insert(query_string, ' '..table.concat(query_obj.select_list, ', '))
  end

  if isstring(query_obj.table_name) then
    table.insert(query_string, ' FROM '..query_obj:quote_column(query_obj.table_name)..' ')
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if istable(query_obj.where_list) and #query_obj.where_list > 0 then
    table.insert(query_string, ' WHERE ')
    table.insert(query_string, table.concat(query_obj.where_list, ' AND '))
  end

  if istable(query_obj.order_list) and #query_obj.order_list > 0 then
    table.insert(query_string, ' ORDER BY ')
    table.insert(query_string, table.concat(query_obj.order_list, ', '))
  end

  if isnumber(query_obj._limit) then
    table.insert(query_string, ' LIMIT ')
    table.insert(query_string, query_obj._limit)
  end

  return table.concat(query_string)
end

local function build_insert_query(query_obj)
  local query_string = { 'INSERT INTO ' }
  local key_list = {}
  local value_list = {}

  if isstring(query_obj.table_name) then
    table.insert(query_string, query_obj:quote_column(query_obj.table_name))
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  for k, v in ipairs(query_obj.insert_list) do
    table.insert(key_list, query_obj:quote_column(v[1]))
    table.insert(value_list, v[2])
  end

  if #key_list == 0 then
    return
  end

  table.insert(query_string, ' ('..table.concat(key_list, ', ')..')')
  table.insert(query_string, ' VALUES ('..table.concat(value_list, ', ')..')')

  return table.concat(query_string)
end

local function build_update_query(query_obj)
  local query_string = { 'UPDATE ' }

  if isstring(query_obj.table_name) then
    table.insert(query_string, query_obj:quote_column(query_obj.table_name))
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if istable(query_obj.update_list) and #query_obj.update_list > 0 then
    local update_list = {}

    table.insert(query_string, ' SET')

    for k, v in ipairs(query_obj.update_list) do
      table.insert(update_list, v[1]..' = '..v[2])
    end

    table.insert(query_string, ' '..table.concat(update_list, ', '))
  end

  if istable(query_obj.where_list) and #query_obj.where_list > 0 then
    table.insert(query_string, ' WHERE ')
    table.insert(query_string, table.concat(query_obj.where_list, ' AND '))
  end

  if isnumber(query_obj.offset) then
    table.insert(query_string, ' OFFSET ')
    table.insert(query_string, query_obj.offset)
  end

  return table.concat(query_string)
end

local function build_delete_query(query_obj)
  local query_string = { 'DELETE FROM ' }

  if isstring(query_obj.table_name) then
    table.insert(query_string, query_obj:quote_column(query_obj.table_name))
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if istable(query_obj.where_list) and #query_obj.where_list > 0 then
    table.insert(query_string, ' WHERE ')
    table.insert(query_string, table.concat(query_obj.where_list, ' AND '))
  end

  if isnumber(query_obj._limit) then
    table.insert(query_string, ' LIMIT ')
    table.insert(query_string, query_obj._limit)
  end

  return table.concat(query_string)
end

local function build_drop_query(query_obj)
  local query_string = { 'DROP TABLE ' }

  if isstring(query_obj.table_name) then
    table.insert(query_string, query_obj:quote_column(query_obj.table_name))
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  return table.concat(query_string)
end

local function build_truncate_query(query_obj)
  local query_string = { 'TRUNCATE TABLE ' }

  if isstring(query_obj.table_name) then
    table.insert(query_string, ' '..query_obj:quote_column(query_obj.table_name))
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  return table.concat(query_string)
end

local function build_create_query(query_obj)
  local query_string = { 'DROP TABLE IF EXISTS ' }

  if !query_obj._overwrite then
    query_string = { 'CREATE TABLE IF NOT EXISTS ' }
  end

  if isstring(query_obj.table_name) then
    table.insert(query_string, query_obj:quote_column(query_obj.table_name))
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
  end

  if query_obj._overwrite then
    table.insert(query_string, ';\nCREATE TABLE '..query_obj:quote_column(query_obj.table_name))
  end

  table.insert(query_string, ' (')

  if istable(query_obj.create_list) and #query_obj.create_list > 0 then
    local create_list = {}

    for k, v in ipairs(query_obj.create_list) do
      if ActiveRecord.adapter.class_name:lower() == 'sqlite' then
        table.insert(create_list, v[1]..' '..string.gsub(string.gsub(string.gsub(v[2], 'AUTO_INCREMENT', ''), 'AUTOINCREMENT', ''), 'INT ', 'INTEGER '))
      else
        table.insert(create_list, v[1]..' '..v[2])
      end
    end

    table.insert(query_string, ' '..table.concat(create_list, ', '))
  end

  if isstring(query_obj.prim_key) and ActiveRecord.adapter_name != 'pg' then
    table.insert(query_string, ', PRIMARY KEY')
    table.insert(query_string, ' ('..query_obj.prim_key..')')
  end

  table.insert(query_string, ' )')

  if query_obj.options then
    table.insert(query_string, ' '..query_obj.options)
  end

  return table.concat(query_string)
end

local function build_change_query(query)
  local query_string = { 'ALTER TABLE ' }

  if isstring(query.table_name) then
    table.insert(query_string, ' '..query:quote_column(query.table_name))
  else
    error_with_traceback('ActiveRecord - No table name specified!')
    return
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

  if #query.create_list > 0 then
    for k, v in ipairs(query.create_list) do
      table.insert(query_string, ' ADD '..v[1]..' '..v[2]..',')
    end
  end

  return table.concat(query_string):Trim():Trim(',')
end

function ActiveRecord.Query:execute(queue_query)
  local query_string = nil
  local query_type = string.lower(self.query_type)

  ActiveRecord.adapter:append_query(self, query_type, queue_query)

  if query_type == 'select' then
    query_string = build_select_query(self)
  elseif query_type == 'insert' then
    query_string = build_insert_query(self)
  elseif query_type == 'update' then
    query_string = build_update_query(self)
  elseif query_type == 'delete' then
    query_string = build_delete_query(self)
  elseif query_type == 'drop' then
    query_string = build_drop_query(self)
  elseif query_type == 'truncate' then
    query_string = build_truncate_query(self)
  elseif query_type == 'create' then
    query_string = build_create_query(self)
  elseif query_type == 'change' then
    query_string = build_change_query(self)
  end

  local hooked = ActiveRecord.adapter:append_query_string(self, query_string, query_type)

  if isstring(hooked) then
    query_string = hooked
  end

  if isstring(query_string) then
    query_string = query_string:ensure_end(';')
    query_string = query_string:gsub(' ;', ';'):gsub('  ', ' ')

    if !queue_query then
      return ActiveRecord.adapter:raw_query(query_string, self._callback, query_type)
    else
      return ActiveRecord.adapter:queue(query_string, self._callback, query_type)
    end
  end
end
