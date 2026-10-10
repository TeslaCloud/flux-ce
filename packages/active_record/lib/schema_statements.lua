--- The schema statements (create_table, add_column, add_index and so on) that the
-- migrations DSL exposes as global functions. The functions in here run their
-- statement right away and keep the in-memory schema and metadata up to date; the
-- global functions of the same name (see helpers.lua) go through ActiveRecord.ddl,
-- which can also record the statements, so that a migration's #change can be reverted.
ActiveRecord.SchemaStatements = ActiveRecord.SchemaStatements or {}

local Statements = ActiveRecord.SchemaStatements

--- Splits the arguments of add_column / remove_column into their parts. Both the
-- positional (name, type, options) form and the table form { name, type = ..., ... }
-- are accepted.
-- @param name [String/Map]
-- @param type=nil [String]
-- @param options=nil [Map]
-- @return [String name, String type, Map options]
function Statements.column_definition(name, type, options)
  if istable(name) then
    local args = table.Copy(name)
    local column = args[1]

    table.remove(args, 1)

    return column, args.type, args
  end

  return name, type, istable(options) and table.Copy(options) or {}
end

local function with_print(query, label)
  query:callback(function(result, query_str, time)
    print_query(label..' ('..time..'s)', query_str)
  end)

  return query
end

local function raw(label, sql)
  return ActiveRecord.adapter:raw_query(sql, function(result, query_str, time)
    print_query(label..' ('..time..'s)', query_str)
  end)
end

--- Creates the indexes and foreign keys that t:references queued on a query.
-- @param table_name [String]
-- @param query [ActiveRecord::Query]
function Statements.apply_references(table_name, query)
  for k, v in ipairs(query._references or {}) do
    if v.index != false then
      Statements.add_index(table_name, { v.column })
    end

    if v.foreign_key then
      local fk = istable(v.foreign_key) and v.foreign_key or {}

      Statements.add_foreign_key(table_name, fk.to_table or v.to_table, {
        column = v.column,
        primary_key = fk.primary_key,
        on_delete = fk.on_delete,
        name = fk.name
      })
    end
  end
end

--- Creates a database table. The 'id' primary key is added automatically.
-- ```
-- create_table('logs', function(t)
--   t:text 'body'
--   t:string { 'action', null = false }
--   t:timestamps()
-- end)
--
-- create_table('users', { force = true }, function(t) ... end)
-- ```
-- @param name [String table name]
-- @param options=nil [Map force (drop an existing table first), if_not_exists (leave an
--   existing table alone), id (false to not add a primary key), primary_key (name of the
--   primary key column, 'id' by default)]
-- @param callback=nil [Function receives the 'create' ActiveRecord::Query to define the
--   columns on]
function Statements.create_table(name, options, callback)
  if isfunction(options) then
    callback, options = options, nil
  end

  options = options or {}

  local query = ActiveRecord.Database:create(name)

  if options.force then
    query:overwrite(true)
    ActiveRecord.drop_from_schema(name)
  elseif options.if_not_exists then
    query:if_not_exists(true)
  end

  if callback then
    callback(query)
  end

  if options.id != false then
    local primary_key = options.primary_key or 'id'
    local quoted = query:quote_column(primary_key)
    local defined = false

    for k, v in ipairs(query.create_list) do
      if v[1] == quoted then defined = true break end
    end

    if !defined then
      query:primary_key(primary_key)

      -- Keep the primary key as the first column of the table.
      table.insert(query.create_list, 1, table.remove(query.create_list))
    end
  end

  with_print(query, 'Create Table'):execute()

  Statements.apply_references(name, query)
end

--- Creates the database table of a model: a table with the 'id' primary key, the given
-- columns and the 'created_at' / 'updated_at' timestamps.
-- @param name [String table name, the lowercase plural of the model's class name]
-- @param callback [Function receives the table definition]
-- @see [create_table]
function Statements.define_model(name, callback)
  Statements.create_table(name, function(t)
    callback(t)
    t:timestamps()
  end)
end

--- Drops a database table, along with what the metadata knows about its indexes and
-- foreign keys.
-- @param name [String table name]
-- @param options=nil [Map if_exists (ignore a missing table)]
function Statements.drop_table(name, options)
  if isfunction(options) then options = nil end

  options = options or {}

  local query = ActiveRecord.Database:drop(name)

  if options.if_exists then
    query:if_exists(true)
  end

  with_print(query, 'Drop Table'):execute()

  ActiveRecord.drop_from_schema(name)

  for index_name, index in pairs(table.Copy(ActiveRecord.metadata.indexes)) do
    if index.table == name then
      ActiveRecord.forget_metadata('index', index_name)
    end
  end

  for fk_name, fk in pairs(table.Copy(ActiveRecord.metadata.references)) do
    if fk.from_table == name then
      ActiveRecord.forget_metadata('foreign_key', fk_name)
    end
  end

  for pk_name, pk in pairs(table.Copy(ActiveRecord.metadata.prim_keys)) do
    if pk.table == name then
      ActiveRecord.forget_metadata('primary_key', pk_name)
    end
  end
end

--- Renames a database table.
-- @param name [String current table name]
-- @param new_name [String]
function Statements.rename_table(name, new_name)
  raw('Rename Table', 'ALTER TABLE '..sql_quote_name(name)..' RENAME TO '..sql_quote_name(new_name)..';')

  ActiveRecord.rename_table_in_schema(name, new_name)

  for index_name, index in pairs(ActiveRecord.metadata.indexes) do
    if index.table == name then
      index.table = new_name
      ActiveRecord.store_metadata('index', index_name, index)
    end
  end

  for fk_name, fk in pairs(ActiveRecord.metadata.references) do
    if fk.from_table == name or fk.to_table == name then
      if fk.from_table == name then fk.from_table = new_name end
      if fk.to_table == name then fk.to_table = new_name end

      ActiveRecord.store_metadata('foreign_key', fk_name, fk)
    end
  end
end

--- Alters an existing database table.
-- ```
-- change_table('users', function(t)
--   t:rename('name', 'nickname')
--   t:remove('banned')
--   t:integer 'playtime'
--   t:references 'faction'
-- end)
-- ```
-- @param name [String table name]
-- @param callback [Function receives the 'change' ActiveRecord::Query to describe the
--   changes on]
function Statements.change_table(name, callback)
  local query = ActiveRecord.Database:change(name)

  callback(query)

  with_print(query, 'Change Table'):execute()

  Statements.apply_references(name, query)
end

--- Adds a column to an existing table.
-- ```
-- add_column('users', 'role', 'string', { default = '\'user\'' })
-- add_column('users', { 'banned', type = 'boolean', default = false })
-- ```
-- @param table_name [String table name]
-- @param name [String/Map column name, or a table holding the name at index 1, the
--   abstract column type under 'type' and the options as keys]
-- @param type=nil [String abstract column type, e.g. 'string', 'integer' or 'datetime']
-- @param options=nil [Map null (Boolean) and default (inserted into the SQL as is)]
function Statements.add_column(table_name, name, type, options)
  name, type, options = Statements.column_definition(name, type, options)

  if !isstring(type) then
    error('add_column - the type of the column '..tostring(table_name)..'.'..tostring(name)..' is missing!', 0)
  end

  Statements.change_table(table_name, function(t)
    if !isfunction(t[type]) then
      error('add_column - unknown column type \''..type..'\'!', 0)
    end

    t[type](t, { name, null = options.null, default = options.default })
  end)
end

--- Removes a column from an existing table.
-- @param table_name [String table name]
-- @param name [String/Map column name, or the same table add_column takes]
-- @param type=nil [String abstract column type; only needed to make the removal
--   reversible]
-- @param options=nil [Map column options; only needed to make the removal reversible]
function Statements.remove_column(table_name, name, type, options)
  name = Statements.column_definition(name, type, options)

  Statements.change_table(table_name, function(t)
    t:remove(name)
  end)

  ActiveRecord.remove_from_schema(table_name, name)
end

--- Renames a column of an existing table.
-- @param table_name [String table name]
-- @param name [String current column name]
-- @param new_name [String]
function Statements.rename_column(table_name, name, new_name)
  Statements.change_table(table_name, function(t)
    t:rename(name, new_name)
  end)

  ActiveRecord.rename_in_schema(table_name, name, new_name)
end

--- Adds the 'created_at' and 'updated_at' columns to an existing table.
-- @param table_name [String]
-- @param options=nil [Map column options, e.g. { null = true }]
function Statements.add_timestamps(table_name, options)
  Statements.change_table(table_name, function(t)
    t:timestamps(options)
  end)
end

--- Removes the 'created_at' and 'updated_at' columns from a table.
-- @param table_name [String]
-- @param options=nil [Map unused]
function Statements.remove_timestamps(table_name, options)
  Statements.remove_column(table_name, 'created_at')
  Statements.remove_column(table_name, 'updated_at')
end

--- Adds a reference column ('<name>_id'), its index and optionally a foreign key to an
-- existing table.
-- @param table_name [String]
-- @param name [String name of the referenced model, singular]
-- @param options=nil [Map the options of t:references]
function Statements.add_reference(table_name, name, options)
  Statements.change_table(table_name, function(t)
    t:references(name, options or {})
  end)
end

--- Removes a reference column along with its index and foreign key.
-- @param table_name [String]
-- @param name [String name of the referenced model, singular]
-- @param options=nil [Map column (defaults to '<name>_id')]
function Statements.remove_reference(table_name, name, options)
  options = options or {}

  local column = options.column or name..'_id'

  for fk_name, fk in pairs(table.Copy(ActiveRecord.metadata.references)) do
    if fk.from_table == table_name and fk.column == column then
      Statements.remove_foreign_key(table_name, { name = fk_name })
    end
  end

  if ActiveRecord.metadata.indexes[Statements.index_name(table_name, { column })] then
    Statements.remove_index(table_name, { column })
  end

  Statements.remove_column(table_name, column, 'integer', options)
end

--- Returns the name an index gets when none is given: '<table>_<columns>_index'.
-- @param table_name [String]
-- @param columns [List<String>]
-- @return [String]
function Statements.index_name(table_name, columns)
  return table_name..'_'..table.concat(columns, '_')..'_index'
end

local function to_column_list(columns)
  if istable(columns) then
    return table.Copy(columns)
  end

  return { columns }
end

--- Creates an index, unless an index with the same name is already recorded in the
-- metadata.
-- ```
-- add_index('users', 'steam_id')
-- add_index('characters', { 'user_id', 'name' }, { unique = true })
-- add_index { 'users', 'steam_id', unique = true }
-- ```
-- @param table_name [String/Map table name, or a table holding the table name at index
--   1, the column(s) at index 2 and the options as keys]
-- @param columns=nil [String/List<String> column name or a list of column names]
-- @param options=nil [Map name, unique, length, using, where and if_not_exists]
function Statements.add_index(table_name, columns, options)
  if istable(table_name) and columns == nil then
    local args = table.Copy(table_name)
    table_name, columns, options = args[1], args[2], args
  end

  if !isstring(table_name) or !columns then return end

  options = options or {}

  local cols = to_column_list(columns)
  local len = options.length
  local index_name = options.name or Statements.index_name(table_name, cols)
  local postgres = ActiveRecord.adapter:is_postgres()
  local sqlite = ActiveRecord.adapter:is_sqlite()

  if ActiveRecord.metadata.indexes[index_name] then return end

  local query = 'CREATE '..(options.unique == true and 'UNIQUE ' or '')..'INDEX '

  if options.if_not_exists then
    query = query..'IF NOT EXISTS '
  end

  query = query..index_name..' ON '..table_name

  local column_parts = {}

  for k, v in ipairs(cols) do
    if len and !sqlite then
      column_parts[k] = v..'('..(istable(len) and len[v] or len)..')'
    else
      column_parts[k] = v
    end
  end

  local column_list = ' ('..table.concat(column_parts, ', ')..')'

  if !postgres then
    query = query..column_list
  end

  if !sqlite then
    query = query..' USING '..(options.using or (postgres and 'btree' or 'BTREE'))
  end

  if postgres then
    query = query..column_list
  end

  if options.where then
    query = query..' WHERE '..options.where
  end

  raw('Add Index', query..';')

  ActiveRecord.store_metadata('index', index_name, {
    table = table_name,
    columns = cols,
    unique = options.unique == true or nil,
    length = len,
    using = options.using,
    where = options.where
  })
end

--- Drops an index and removes it from the metadata.
-- ```
-- remove_index('users', 'steam_id')
-- remove_index('characters', { 'user_id', 'name' })
-- remove_index('users', { name = 'users_steam_id_index' })
-- remove_index('users', { column = 'steam_id', if_exists = true })
-- ```
-- @param table_name [String]
-- @param options [String/List<String>/Map column name, list of column names, or a table
--   with name or column(s) and optionally if_exists]
function Statements.remove_index(table_name, options)
  local index_name = nil
  local if_exists = false

  if isstring(options) then
    index_name = Statements.index_name(table_name, { options })
  elseif istable(options) then
    if options.name then
      index_name = options.name
    elseif options.column then
      index_name = Statements.index_name(table_name, to_column_list(options.column))
    elseif options[1] then
      index_name = Statements.index_name(table_name, options)
    end

    if_exists = options.if_exists == true
  end

  if !index_name then
    error('remove_index - no index name or columns given for table '..tostring(table_name)..'!', 0)
  end

  local query = 'DROP INDEX '..(if_exists and 'IF EXISTS ' or '')..index_name

  if ActiveRecord.adapter:is_mysql() then
    query = query..' ON '..table_name
  end

  raw('Remove Index', query..';')

  ActiveRecord.forget_metadata('index', index_name)
end

--- Returns the name a foreign key constraint gets when none is given.
-- @param from_table [String]
-- @param column [String]
-- @param to_table [String]
-- @param primary_key [String]
-- @return [String]
function Statements.foreign_key_name(from_table, column, to_table, primary_key)
  return 'ar_'..util.CRC(column..primary_key..from_table..to_table)
end

local on_delete_clauses = {
  cascade = 'CASCADE',
  nullify = 'SET NULL',
  restrict = 'RESTRICT'
}

--- Adds a foreign key constraint. Does nothing if a constraint with the same name is
-- already recorded in the metadata. SQLite cannot add constraints to existing tables, so
-- the constraint is only recorded there.
-- ```
-- add_foreign_key('characters', 'users')
-- add_foreign_key('characters', 'users', { column = 'owner_id', on_delete = 'cascade' })
-- ```
-- @param from_table [String table that holds the key]
-- @param to_table [String table the key refers to]
-- @param options=nil [Map column (defaults to '<singular of to_table>_id'), primary_key
--   ('id' by default), on_delete ('cascade', 'nullify' or 'restrict') and name]
function Statements.add_foreign_key(from_table, to_table, options)
  options = options or {}

  if !isstring(to_table) then
    error('add_foreign_key - the referenced table of '..tostring(from_table)..' is missing!', 0)
  end

  local column = options.column or Flow.Inflector:singularize(to_table)..'_id'
  local primary_key = options.primary_key or 'id'
  local name = options.name or Statements.foreign_key_name(from_table, column, to_table, primary_key)

  if ActiveRecord.metadata.references[name] then return end

  if !ActiveRecord.adapter:is_sqlite() then
    local query = 'ALTER TABLE '..from_table..' ADD CONSTRAINT '..name
      ..' FOREIGN KEY ('..column..') REFERENCES '..to_table..'('..primary_key..')'

    if options.on_delete then
      query = query..' ON DELETE '..(on_delete_clauses[options.on_delete] or tostring(options.on_delete):upper())
    end

    raw('Add Foreign Key', query..';')
  end

  ActiveRecord.store_metadata('foreign_key', name, {
    from_table = from_table,
    to_table = to_table,
    column = column,
    primary_key = primary_key,
    on_delete = options.on_delete
  })
end

--- Drops a foreign key constraint and removes it from the metadata.
-- ```
-- remove_foreign_key('characters', 'users')
-- remove_foreign_key('characters', { column = 'owner_id' })
-- remove_foreign_key('characters', { name = 'ar_123456' })
-- ```
-- @param from_table [String table that holds the key]
-- @param to_table [String/Map table the key refers to, or the options]
-- @param options=nil [Map column or name of the constraint]
function Statements.remove_foreign_key(from_table, to_table, options)
  if istable(to_table) then
    options, to_table = to_table, nil
  end

  options = options or {}

  local name = options.name

  if !name then
    for fk_name, fk in pairs(ActiveRecord.metadata.references) do
      if fk.from_table == from_table and
        ((options.column and fk.column == options.column) or (to_table and fk.to_table == to_table)) then
        name = fk_name
        break
      end
    end
  end

  if !name then
    error('remove_foreign_key - no foreign key found on '..tostring(from_table)..'!', 0)
  end

  if ActiveRecord.adapter:is_mysql() then
    raw('Remove Foreign Key', 'ALTER TABLE '..from_table..' DROP FOREIGN KEY '..name..';')
  elseif !ActiveRecord.adapter:is_sqlite() then
    raw('Remove Foreign Key', 'ALTER TABLE '..from_table..' DROP CONSTRAINT '..name..';')
  end

  ActiveRecord.forget_metadata('foreign_key', name)
end

--- Adds a foreign key constraint along with an index on the key column.
-- ```
-- create_reference {
--   table_name = 'characters', key = 'user_id',
--   foreign_table = 'users', foreign_key = 'id',
--   cascade = true
-- }
-- ```
-- @param args [Map table_name, key, foreign_table and foreign_key, optionally cascade
--   (Boolean, adds ON DELETE CASCADE) and name (name of the constraint)]
function Statements.create_reference(args)
  Statements.add_index(args.table_name, { args.key })
  Statements.add_foreign_key(args.table_name, args.foreign_table, {
    column = args.key,
    primary_key = args.foreign_key,
    on_delete = tobool(args.cascade) and 'cascade' or nil,
    name = args.name
  })
end

--- Adds a PRIMARY KEY constraint named '<table_name>_pkey' to a table, unless it is
-- already recorded in the metadata.
-- @param table_name [String]
-- @param key [String column name]
function Statements.create_primary_key(table_name, key)
  local pkey_name = table_name..'_pkey'

  if ActiveRecord.metadata.prim_keys[pkey_name] then return end

  raw('Create Primary Key', 'ALTER TABLE '..table_name..' ADD CONSTRAINT '..pkey_name..' PRIMARY KEY ('..key..');')

  ActiveRecord.store_metadata('primary_key', pkey_name, { table = table_name, column = key })
end

--- Runs a raw SQL statement.
-- @param sql [String]
-- @return [Any whatever the adapter returns]
function Statements.execute(sql)
  return raw('Execute', sql)
end

--- Runs a function. Used by Migration#reversible to put a block of code into the list
-- of recorded statements.
-- @param callback [Function]
function Statements.execute_block(callback)
  callback()
end
