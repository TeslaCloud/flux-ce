function create_table(name, callback)
  local query = ActiveRecord.Database:create(name)
    callback(query)
    query:callback(function(result, query, time)
      print_query('Create Table ('..time..'ms)', query)
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
    query:callback(function(result, query, time)
      print_query('Change Table ('..time..'ms)', query)
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

function add_column(table, name, type)
  change_table(table, function(t)
    t[type](t, name)
  end)
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

    if len and ActiveRecord.adapter_name != 'sqlite' then
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

  ActiveRecord.Database:raw_query(query)
end

function to_datetime(unix_time)
  return os.date('%Y-%m-%d %H:%M:%S', unix_time)
end

function print_query(prefix, query)
  if !IS_PRODUCTION then
    MsgC(Color('cyan'), '  '..prefix..' ')
    MsgC(Color(0, 55, 218), query)
    Msg('\n')
  end
end
