function create_table(name, callback)
  local query = ActiveRecord.Database:create(name)
    query:overwrite(true)
    callback(query)
    query:callback(function(result, query_str, time)
      print_query('Create Table ('..time..'ms)', query_str)
    end)
  query:execute()
end

function drop_table(name)
  local query = ActiveRecord.Database:drop(name)
    query:callback(function(result, query, time)
      print_query('Drop Table ('..time..'ms)', query)
    end)
  return query:execute()
end

function change_table(name, callback)
  local query = ActiveRecord.Database:change(name)
    callback(query)
    query:callback(function(result, query_str, time)
      print_query('Change Table ('..time..'ms)', query_str)
    end)
  query:execute()
end

function rename_column(table, name, new_name)
  change_table(table, function(t)
    t:rename(name, new_name)
  end)
end

function remove_column(table, name)
  change_table(table, function(t)
    t:remove(name)
  end)
end

function add_column(table, args)
  change_table(table, function(t)
    t[args.type](t, args)
  end)
end

function add_index(args)
  if !isstring(args[1]) or !args[2] then return end

  local cols = istable(args[2]) and args[2] or { args[2] }
  local len = args['length']
  local index_name = args['name'] or args[1]..'_'..table.concat(cols, '_')..'_index'
  local postgres = ActiveRecord.adapter:is_postgres()
  local sqlite = ActiveRecord.adapter:is_sqlite()

  if ActiveRecord.metadata.indexes[index_name] then return end

  local query = 'CREATE '..(args['unique'] == true and 'UNIQUE ' or '')..'INDEX '

  if args['if_not_exists'] then
    query = query..' IF NOT EXISTS '
  end

  query = query..index_name

  query = query..' ON '..args[1]

  local function _columns(query)
    query = query..' ('

    for k, v in ipairs(cols) do
      query = query..v

      if len and !sqlite then
        query = query..'('..(istable(len) and len[v] or len)..')'
      end

      if k != #cols then
        query = query..', '
      end
    end

    query = query..')'

    return query
  end

  if !postgres then
    query = _columns(query)
  end

  if !sqlite then
    query = query..' USING '..(args['using'] or (postgres and 'btree' or 'BTREE'))
  end

  if postgres then
    query = _columns(query)
  end

  if args['where'] then
    query = query..' WHERE '..args['where']
  end

  query = query..';'

  ActiveRecord.metadata.indexes[index_name] = args

  ActiveRecord.adapter:raw_query(query, function(results, query_str, time)
    print_query('Add Index ('..time..'ms)', query_str)
  end)
end

function drop_index(index_name, table_name)
  ActiveRecord.metadata.indexes[index_name] = nil

  ActiveRecord.adapter:raw_query('DROP INDEX IF EXISTS '..index_name..' ON '..table_name..';', function(results, query_str, time)
    print_query('Drop Index ('..time..'ms)', query_str)
  end)
end

function create_reference(args)
  local table_name, key, foreign_table, foreign_key, cascade = args.table_name, args.key, args.foreign_table, args.foreign_key, args.cascade

  add_index { table_name, key }

  local constraint_name = args.name or 'ar_'..util.CRC(key..foreign_key..table_name..foreign_table)

  if ActiveRecord.metadata.references[constraint_name] then return end

  local query = 'ALTER TABLE '..table_name
    ..' ADD CONSTRAINT '..constraint_name
    ..' FOREIGN KEY ('..key..') REFERENCES '
    ..foreign_table..'('..foreign_key..')'
  query = query..(cascade and ' ON DELETE CASCADE;' or ';')

  ActiveRecord.metadata.references[constraint_name] = args

  ActiveRecord.adapter:raw_query(query, function(result, query_str, time)
    print_query('Create Reference ('..time..'ms)', query_str)
  end)
end

function create_primary_key(table_name, key)
  local pkey_name = table_name..'_pkey'

  if ActiveRecord.metadata.prim_keys[pkey_name] then return end

  ActiveRecord.metadata.prim_keys[pkey_name] = { table_name, key }
  ActiveRecord.adapter:raw_query('ALTER TABLE '..table_name
    ..' ADD CONSTRAINT '..pkey_name
    ..' PRIMARY KEY ('..key..');', function(result, query_str, time)
      print_query('Create Primary Key ('..time..'ms)', query_str)
  end)
end

function to_datetime(unix_time)
  return os.date('%Y-%m-%d %H:%M:%S', unix_time)
end

function to_timestamp(unix_time)
  return os.date('%Y%m%d%H%M%S', unix_time)
end

do
  local indent_level = 1

  function ar_get_indent()
    return indent_level
  end

  function ar_set_indent(lvl)
    indent_level = lvl or 1
    return indent_level
  end

  function ar_add_indent()
    indent_level = indent_level + 1
    return indent_level
  end

  function ar_sub_indent()
    indent_level = indent_level - 1
    return indent_level
  end

  function print_query(prefix, query)
    if !IS_PRODUCTION then
      MsgC(Color('cyan'), string.rep('  ', indent_level)..prefix..' ')
      MsgC(Color(100, 220, 100), query)
      Msg('\n')
    end
  end
end

function time_from_timestamp(timestamp)
  local yy, mm, dd, hh, m, ss = string.match(timestamp, '(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
  return os.time({
    year = yy,
    month = mm,
    day = dd,
    hour = hh,
    min = m,
    sec = ss
  })
end
