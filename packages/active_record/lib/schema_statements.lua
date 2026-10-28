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
  query:callback(function(_result, query_str, time, bindings)
    print_query(label..' ('..time..'s)', query_str, bindings)
  end)

  return query
end

local function raw(label, sql, bindings)
  return ActiveRecord.adapter:raw_query(sql, function(_result, query_str, time)
    print_query(label..' ('..time..'s)', query_str, bindings)
  end, nil, bindings)
end

--- Creates the indexes and foreign keys that t:references queued on a query.
-- @param table_name [String]
-- @param query [ActiveRecord::Query]
function Statements.apply_references(table_name, query)
  for _, reference in ipairs(query._references or {}) do
    if reference.index != false then
      Statements.add_index(table_name, { reference.column })
    end

    if reference.foreign_key then
      local fk = istable(reference.foreign_key) and reference.foreign_key or {}

      Statements.add_foreign_key(table_name, fk.to_table or reference.to_table, {
        column = reference.column,
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

    for _, column_def in ipairs(query.create_list) do
      if column_def[1] == quoted then defined = true break end
    end

    if !defined then
      query:primary_key(primary_key)

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

--- Checks whether the SQL of an index names one of the given columns.
-- @param index_sql [String the CREATE INDEX statement]
-- @param columns [Map column names, as keys]
-- @return [Boolean]
local function index_covers(index_sql, columns)
  local column_list = index_sql:match('%((.*)%)%s*$') or index_sql

  for column in pairs(columns) do
    local escaped = column:gsub('%p', '%%%0')

    for _, part in ipairs(string.Explode(',', column_list)) do
      local name = string.Trim(part):match('^[%["`]?([^%]"`%s]+)')

      if name and name:find('^'..escaped..'$') then
        return true
      end
    end
  end

  return false
end

local function rows(result)
  return result
end

local function sqlite_table_names()
  local result = ActiveRecord.adapter:raw_query(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name;", rows
  )
  local names = {}

  for _, row in ipairs(istable(result) and result or {}) do
    names[#names + 1] = row.name
  end

  return names
end

local function sqlite_table_sql(table_name)
  local result = ActiveRecord.adapter:raw_query(
    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?;", rows, 'select', { table_name }
  )

  return istable(result) and result[1] and result[1].sql or nil
end

local function sqlite_autoincrement(table_name)
  local definition = sqlite_table_sql(table_name)

  return isstring(definition) and definition:upper():find('%f[%w_]AUTOINCREMENT%f[^%w_]') != nil
end

--- Returns the column of an SQLite table that SQLite makes AUTOINCREMENT if asked to: a
-- single primary key column of the INTEGER type.
-- @param columns [List<Map> the columns, as PRAGMA table_info returns them]
-- @return [String the name of the column, or nil]
local function sqlite_integer_primary_key(columns)
  local found = nil

  for _, column in ipairs(columns) do
    if tonumber(column.pk) and tonumber(column.pk) > 0 then
      if found or tonumber(column.pk) != 1 or tostring(column.type):upper() != 'INTEGER' then
        return
      end

      found = column.name
    end
  end

  return found
end

--- Reads the last id that SQLite has given out for an AUTOINCREMENT table.
-- @param table_name [String]
-- @return [Number 0 if the table has given out none or is not AUTOINCREMENT]
local function sqlite_sequence(table_name)
  if !sqlite_table_sql('sqlite_sequence') then return 0 end

  local result = ActiveRecord.adapter:raw_query(
    'SELECT seq FROM sqlite_sequence WHERE name = ?;', rows, 'select', { table_name }
  )

  return istable(result) and result[1] and tonumber(result[1].seq) or 0
end

--- Reads the foreign keys of an SQLite table.
-- @param table_name [String]
-- @return [List<Map> the foreign keys, each with the List<String> of its columns (from),
--   the table it refers to (table), the List<String> of the referenced columns (to, empty
--   for the primary key) and its on_update and on_delete actions]
local function sqlite_foreign_keys(table_name)
  local result = ActiveRecord.adapter:raw_query(
    'PRAGMA foreign_key_list('..sql_quote_name(table_name)..');', rows
  )
  local by_id = {}
  local list = {}

  for _, row in ipairs(istable(result) and result or {}) do
    local id = tonumber(row.id) or 0
    local fk = by_id[id]

    if !fk then
      fk = { id = id, from = {}, to = {}, table = row.table, on_update = row.on_update, on_delete = row.on_delete }
      by_id[id] = fk
      list[#list + 1] = fk
    end

    local seq = (tonumber(row.seq) or 0) + 1

    fk.from[seq] = row.from

    if isstring(row.to) and row.to != '' and row.to != 'NULL' then
      fk.to[seq] = row.to
    end
  end

  table.sort(list, function(a, b) return a.id > b.id end)

  return list
end

local function find_sqlite_foreign_key(table_name, column, to_table)
  for _, fk in ipairs(sqlite_foreign_keys(table_name)) do
    if #fk.from == 1 and fk.from[1] == column and fk.table == to_table then
      return fk
    end
  end
end

local function foreign_key_clause(fk)
  local function quote_all(names)
    local quoted = {}

    for index, name in ipairs(names) do
      quoted[index] = sql_quote_name(name)
    end

    return table.concat(quoted, ', ')
  end

  local parts = { 'FOREIGN KEY ('..quote_all(fk.from)..') REFERENCES '..sql_quote_name(fk.table) }

  if #fk.to > 0 then
    parts[#parts + 1] = '('..quote_all(fk.to)..')'
  end

  for _, action in ipairs({ 'on_update', 'on_delete' }) do
    local value = isstring(fk[action]) and fk[action]:upper() or 'NO ACTION'

    if value != 'NO ACTION' then
      parts[#parts + 1] = action:upper():gsub('_', ' ')..' '..value
    end
  end

  return table.concat(parts, ' ')
end

--- Explains why an SQLite table cannot be rebuilt by rebuild_sqlite_table: its definition
-- holds something that the rebuild would not carry over.
-- @param table_name [String]
-- @return [String the reason, or nil if the table can be rebuilt]
local function sqlite_rebuild_refusal(table_name)
  local columns = ActiveRecord.adapter:raw_query('PRAGMA table_info('..sql_quote_name(table_name)..');', rows)

  if !istable(columns) then
    return 'the table does not exist'
  end

  local upper = (sqlite_table_sql(table_name) or ''):upper()
  local primary_keys = 0

  for _, column in ipairs(columns) do
    if tonumber(column.pk) and tonumber(column.pk) > 0 then
      primary_keys = primary_keys + 1
    end
  end

  for _, keyword in ipairs({ 'UNIQUE', 'CHECK', 'COLLATE', 'GENERATED' }) do
    if upper:find('%f[%w_]'..keyword..'%f[^%w_]') then
      return 'it has a '..keyword..' clause'
    end
  end

  if primary_keys > 1 then
    return 'it has a composite primary key'
  end
end

--- Runs a function that rebuilds SQLite tables while foreign keys are not enforced, since
-- dropping a table would otherwise delete the rows that refer to it through a foreign key
-- with ON DELETE CASCADE. Outside of a transaction, the enforcement is turned off for the
-- function, which runs in a transaction of its own; the transaction is rolled back if the
-- function fails or leaves more rows breaking a foreign key than there were before. Inside of
-- a transaction, the enforcement cannot be changed: the migrator turns it off before it
-- starts the transaction of a migration and checks the foreign keys before it commits, and
-- the function is refused inside of a transaction that enforces them.
-- @param statement [String name of the schema statement, used in error messages]
-- @param subject [String what is rebuilt, e.g. 'the SQLite table users', used in error
--   messages]
-- @param table_name=nil [String only check the rows of this table for broken foreign keys]
-- @param callback [Function]
-- @return [Any whatever the function returns]
local function without_sqlite_foreign_keys(statement, subject, table_name, callback)
  local adapter = ActiveRecord.adapter

  if adapter:in_transaction() then
    if adapter:foreign_keys_enabled() then
      error(statement..' - cannot rebuild '..subject
        ..' inside of a transaction while foreign keys are enforced!', 0)
    end

    return callback()
  end

  local enforced = adapter:disable_foreign_keys()

  if adapter:foreign_keys_enabled() then
    error(statement..' - cannot rebuild '..subject
      ..', the enforcement of foreign keys could not be turned off!', 0)
  end

  local raise_errors = adapter._raise_errors
  local violations = adapter:foreign_key_violations(table_name)

  adapter:raise_errors(true)
  adapter:begin_transaction()

  local success, result = pcall(function()
    local value = callback()

    adapter:check_foreign_keys(table_name, violations)

    return value
  end)

  if success then
    adapter:commit_transaction()
  else
    adapter:rollback_transaction()
  end

  adapter:raise_errors(raise_errors)

  if enforced then
    adapter:enable_foreign_keys()
  end

  if !success then
    error(result, 0)
  end

  return result
end

--- Rebuilds an SQLite table, which is how columns are removed from a table, foreign keys are
-- added to or removed from it and its primary key is made AUTOINCREMENT on the SQLite of
-- Garry's Mod, since its ALTER TABLE can do none of these. The table is created anew with
-- the remaining columns, each with its declared type, NOT NULL, DEFAULT and a single-column
-- primary key, and with its foreign keys; the rows are copied over, and the indexes that do
-- not name a removed column are created again. A primary key of the INTEGER type is always
-- made AUTOINCREMENT, and the last id that the table has given out is kept, or set to the
-- highest id of its rows if that is higher, so that no id is given out again. Tables that
-- have anything else in their definition, such as a composite primary key or a UNIQUE,
-- CHECK or COLLATE clause, are refused with an error rather than rebuilt without it.
--
-- The rebuild runs while foreign keys are not enforced (see without_sqlite_foreign_keys);
-- outside of a transaction it is rolled back if it leaves more rows of the table breaking one
-- of its foreign keys than before, as adding a foreign key that rows already break does.
-- @param statement [String name of the schema statement, used in error messages]
-- @param table_name [String]
-- @param changes=nil [Map removed (names of the columns to remove, as keys), foreign_keys
--   (List of the foreign keys to add, as returned by sqlite_foreign_keys) and
--   drop_foreign_key (Function that receives a foreign key of the table and returns true to
--   remove it)]
local function rebuild_sqlite_table(statement, table_name, changes)
  changes = changes or {}

  local adapter = ActiveRecord.adapter
  local quoted_table = sql_quote_name(table_name)
  local removed = changes.removed or {}

  if !sqlite_table_sql(table_name) then
    error(statement..' - the table '..tostring(table_name)..' does not exist!', 0)
  end

  local refusal = sqlite_rebuild_refusal(table_name)

  if refusal then
    error(statement..' - cannot rebuild the SQLite table '..table_name..', '..refusal..'!', 0)
  end

  if adapter:in_transaction() and adapter:foreign_keys_enabled() then
    error(statement..' - cannot rebuild the SQLite table '..table_name
      ..' inside of a transaction while foreign keys are enforced!', 0)
  end

  local columns = adapter:raw_query('PRAGMA table_info('..quoted_table..');', rows)
  local primary_key = sqlite_integer_primary_key(columns)
  local indexes = adapter:raw_query(
    "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = ? AND sql IS NOT NULL;",
    rows, 'select', { table_name }
  ) or {}

  local definitions = {}
  local kept = {}

  for _, column in ipairs(columns) do
    if !removed[column.name] then
      local quoted = sql_quote_name(column.name)
      local definition = quoted..' '..(column.type or '')

      if column.name == primary_key then
        definition = definition..' PRIMARY KEY AUTOINCREMENT'
      elseif tonumber(column.pk) == 1 then
        definition = definition..' PRIMARY KEY'
      end

      if tonumber(column.notnull) == 1 then
        definition = definition..' NOT NULL'
      end

      if column.dflt_value != nil and column.dflt_value != 'NULL' then
        definition = definition..' DEFAULT '..column.dflt_value
      end

      definitions[#definitions + 1] = definition
      kept[#kept + 1] = quoted
    end
  end

  for _, fk in ipairs(sqlite_foreign_keys(table_name)) do
    local keep = !(changes.drop_foreign_key and changes.drop_foreign_key(fk))

    for _, column in ipairs(fk.from) do
      if removed[column] then keep = false end
    end

    if keep then
      definitions[#definitions + 1] = foreign_key_clause(fk)
    end
  end

  for _, fk in ipairs(changes.foreign_keys or {}) do
    definitions[#definitions + 1] = foreign_key_clause(fk)
  end

  local temporary = sql_quote_name(table_name..'_rebuilt')
  local column_list = table.concat(kept, ', ')

  local function rebuild()
    local last_id = primary_key and sqlite_sequence(table_name) or 0

    raw('Rebuild Table', 'CREATE TABLE '..temporary..' ('..table.concat(definitions, ', ')..');')
    raw('Rebuild Table',
      'INSERT INTO '..temporary..' ('..column_list..') SELECT '..column_list..' FROM '..quoted_table..';')
    raw('Rebuild Table', 'DROP TABLE '..quoted_table..';')
    raw('Rebuild Table', 'ALTER TABLE '..temporary..' RENAME TO '..quoted_table..';')

    for _, index in ipairs(indexes) do
      if !index_covers(index.sql, removed) then
        raw('Rebuild Table', index.sql..';')
      end
    end

    if last_id > sqlite_sequence(table_name) then
      raw('Rebuild Table', 'DELETE FROM sqlite_sequence WHERE name = ?;', { table_name })
      raw('Rebuild Table', 'INSERT INTO sqlite_sequence (name, seq) VALUES (?, ?);', { table_name, last_id })
    end
  end

  without_sqlite_foreign_keys(statement, 'the SQLite table '..table_name, table_name, rebuild)

  for _, index in ipairs(indexes) do
    if index_covers(index.sql, removed) then
      ActiveRecord.forget_metadata('index', index.name)
    end
  end
end

local function normalize_on_delete(on_delete)
  local action = isstring(on_delete) and on_delete:lower() or 'no action'

  if action == 'set null' then
    return 'nullify'
  end

  return action
end

--- Builds the condition that the rows of a table meet when their column refers to a row of
-- another table that does not exist. The referenced keys are read through a derived table,
-- which MySQL needs to read them from the table that the rows are deleted from.
-- @param column [String]
-- @param to_table [String]
-- @param primary_key [String]
-- @return [String]
local function orphan_condition(column, to_table, primary_key)
  local quoted_column = sql_quote_name(column)
  local quoted_key = sql_quote_name(primary_key)

  return quoted_column..' IS NOT NULL AND '..quoted_column..' NOT IN (SELECT '..quoted_key
    ..' FROM (SELECT '..quoted_key..' FROM '..sql_quote_name(to_table)..') referenced_keys)'
end

--- Counts the rows of a table whose column refers to a row of another table that does not
-- exist. Has to be called while the adapter is in sync mode.
-- @param from_table [String]
-- @param column [String]
-- @param to_table [String]
-- @param primary_key [String]
-- @return [Number]
local function count_orphans(from_table, column, to_table, primary_key)
  local result = ActiveRecord.adapter:raw_query(
    'SELECT COUNT(*) AS orphans FROM '..sql_quote_name(from_table)..' WHERE '
      ..orphan_condition(column, to_table, primary_key)..';',
    rows
  )

  return istable(result) and result[1] and tonumber(result[1].orphans) or 0
end

--- Removes a column from an existing table. On SQLite the table is rebuilt without the
-- column, which only works for tables whose definition the rebuild can carry over; see
-- rebuild_sqlite_table.
-- @param table_name [String table name]
-- @param name [String/Map column name, or the same table add_column takes]
-- @param type=nil [String abstract column type; only needed to make the removal
--   reversible]
-- @param options=nil [Map column options; only needed to make the removal reversible]
function Statements.remove_column(table_name, name, type, options)
  name = Statements.column_definition(name, type, options)

  if ActiveRecord.adapter:is_sqlite() then
    rebuild_sqlite_table('remove_column', table_name, { removed = { [name] = true } })
  else
    Statements.change_table(table_name, function(t)
      t:remove(name)
    end)
  end

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
-- @param _options=nil [Map unused]
function Statements.remove_timestamps(table_name, _options)
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

  for index, column in ipairs(cols) do
    if len and !sqlite then
      column_parts[index] = column..'('..(istable(len) and len[column] or len)..')'
    else
      column_parts[index] = column
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
-- already recorded in the metadata. On SQLite, which cannot add constraints to existing
-- tables, the table is rebuilt with the foreign key (see rebuild_sqlite_table), unless it
-- has one from the same column to the same table already.
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

  local on_delete = options.on_delete
    and (on_delete_clauses[options.on_delete] or tostring(options.on_delete):upper())

  if ActiveRecord.adapter:is_sqlite() then
    if !find_sqlite_foreign_key(from_table, column, to_table) then
      rebuild_sqlite_table('add_foreign_key', from_table, {
        foreign_keys = {
          { from = { column }, table = to_table, to = { primary_key }, on_delete = on_delete }
        }
      })
    end
  else
    local query = 'ALTER TABLE '..from_table..' ADD CONSTRAINT '..name
      ..' FOREIGN KEY ('..column..') REFERENCES '..to_table..'('..primary_key..')'

    if on_delete then
      query = query..' ON DELETE '..on_delete
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

--- Drops a foreign key constraint and removes it from the metadata. On SQLite, the table is
-- rebuilt without the foreign key (see rebuild_sqlite_table) if it has it.
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
  elseif ActiveRecord.adapter:is_sqlite() then
    local fk = ActiveRecord.metadata.references[name]

    if fk and find_sqlite_foreign_key(from_table, fk.column, fk.to_table) then
      rebuild_sqlite_table('remove_foreign_key', from_table, {
        drop_foreign_key = function(existing)
          return #existing.from == 1 and existing.from[1] == fk.column and existing.table == fk.to_table
        end
      })
    end
  else
    raw('Remove Foreign Key', 'ALTER TABLE '..from_table..' DROP CONSTRAINT '..name..';')
  end

  ActiveRecord.forget_metadata('foreign_key', name)
end

--- Checks whether a foreign key is recorded in the metadata.
-- ```
-- foreign_key_exists('characters', 'users')
-- foreign_key_exists('items', { column = 'dropped_by_character_id' })
-- ```
-- @param from_table [String table that holds the key]
-- @param to_table=nil [String/Map table the key refers to, or the options]
-- @param options=nil [Map column or name of the constraint]
-- @return [Boolean]
function Statements.foreign_key_exists(from_table, to_table, options)
  if istable(to_table) then
    options, to_table = to_table, nil
  end

  options = options or {}

  if options.name then
    return ActiveRecord.metadata.references[options.name] != nil
  end

  for _, fk in pairs(ActiveRecord.metadata.references) do
    if fk.from_table == from_table and (!to_table or fk.to_table == to_table)
      and (!options.column or fk.column == options.column) then
      return true
    end
  end

  return false
end

--- Checks whether a table is part of the schema that ActiveRecord keeps, which holds every
-- table created through it.
-- @param table_name [String]
-- @return [Boolean]
function Statements.table_exists(table_name)
  return istable(ActiveRecord.schema[table_name])
end

--- Applies the ON DELETE action of a foreign key to the rows that refer to rows that do not
-- exist, the way the database applies it to the rows of a referenced row that is deleted:
-- with 'cascade' the rows are deleted, with 'nullify' their column is set to NULL. Rows of a
-- foreign key with any other action, and rows whose column cannot be NULL, are left as they
-- are and only counted. A foreign key can only be added to a table once none of its rows
-- refers to a row that does not exist, so this is run before a foreign key is added to a
-- table that already holds rows. The rows that are deleted are not followed further: the
-- rows that refer to them are left for the foreign keys of their own table. Has to be called
-- while the adapter is in sync mode.
-- ```
-- clean_orphans('character_permissions', 'characters', { on_delete = 'cascade' })
-- add_foreign_key('character_permissions', 'characters', { on_delete = 'cascade' })
-- ```
-- @param from_table [String table that holds the key]
-- @param to_table [String table the key refers to]
-- @param options=nil [Map column (defaults to '<singular of to_table>_id'), primary_key
--   ('id' by default) and on_delete ('cascade', 'nullify', or anything else to leave the
--   rows alone)]
-- @return [Number the rows that were deleted or set to NULL, or that are left as they are;
--   String what was done with them: 'deleted', 'nullified' or 'kept']
function Statements.clean_orphans(from_table, to_table, options)
  options = options or {}

  local column = options.column or Flow.Inflector:singularize(to_table)..'_id'
  local primary_key = options.primary_key or 'id'
  local action = normalize_on_delete(options.on_delete)
  local count = count_orphans(from_table, column, to_table, primary_key)
  local schema_column = istable(ActiveRecord.schema[from_table]) and ActiveRecord.schema[from_table][column]

  if action == 'nullify' and istable(schema_column) and schema_column.null == false then
    action = 'not null'
  end

  if count == 0 or (action != 'cascade' and action != 'nullify') then
    return count, 'kept'
  end

  local condition = orphan_condition(column, to_table, primary_key)
  local result = nil

  if action == 'cascade' then
    raw('Clean Orphans', 'DELETE FROM '..sql_quote_name(from_table)..' WHERE '..condition..';')
    result = 'deleted'
  else
    raw('Clean Orphans', 'UPDATE '..sql_quote_name(from_table)..' SET '..sql_quote_name(column)
      ..' = NULL WHERE '..condition..';')
    result = 'nullified'
  end

  if result == 'deleted' then
    print('ActiveRecord - Deleted '..count..' row(s) of '..from_table..' whose '..column
      ..' referred to a row of '..to_table..' that does not exist.')
  else
    print('ActiveRecord - Set '..from_table..'.'..column..' to NULL in '..count
      ..' row(s) that referred to a row of '..to_table..' that does not exist.')
  end

  return count, result
end

--- Creates the foreign keys that the metadata declares but the tables of an SQLite database
-- do not have, such as those of a table that was created or copied without them. Does
-- nothing on other databases, which create a foreign key when it is declared, and on an
-- SQLite database that has every declared foreign key.
--
-- Before the foreign keys are created, the rows that refer to rows that do not exist through
-- any foreign key of the database, declared or created, are dealt with by the action of that
-- foreign key (see clean_orphans), over and over until the deleted rows leave no more such
-- rows behind. A foreign key whose rows still refer to rows that do not exist then, because
-- its action is neither 'cascade' nor 'nullify', is not created: a warning names the table,
-- the column and the number of those rows, which are left untouched. The tables are rebuilt
-- to create the foreign keys (see rebuild_sqlite_table), each table once, and a table that
-- cannot be rebuilt is left without them, with a warning. What has been cleaned and created
-- is printed. Runs in a transaction of its own while foreign keys are not enforced, unless it
-- is called inside of a migration, which runs in one already.
-- @return [Map numbers of the foreign keys that were created (created) and of those that were
--   left out (skipped), and of the rows that were deleted (deleted) and set to NULL
--   (nullified)]
function Statements.add_missing_foreign_keys()
  local summary = { created = 0, skipped = 0, deleted = 0, nullified = 0 }

  if !ActiveRecord.adapter:is_sqlite() then return summary end

  local tables = {}

  for _, table_name in ipairs(sqlite_table_names()) do
    tables[table_name] = true
  end

  local foreign_keys = {}
  local by_key = {}
  local missing = {}

  local function remember(fk)
    local key = fk.from_table..'.'..fk.column..' -> '..fk.to_table

    if by_key[key] then return by_key[key] end

    by_key[key] = fk
    foreign_keys[#foreign_keys + 1] = fk

    return fk
  end

  for _name, fk in SortedPairs(ActiveRecord.metadata.references) do
    if istable(fk) and isstring(fk.from_table) and isstring(fk.to_table) then
      if tables[fk.from_table] and tables[fk.to_table] then
        local declared = remember({
          from_table = fk.from_table,
          to_table = fk.to_table,
          column = fk.column or Flow.Inflector:singularize(fk.to_table)..'_id',
          primary_key = fk.primary_key or 'id',
          on_delete = fk.on_delete
        })

        if !find_sqlite_foreign_key(declared.from_table, declared.column, declared.to_table) then
          missing[#missing + 1] = declared
        end
      end
    end
  end

  if #missing == 0 then return summary end

  for table_name in SortedPairs(tables) do
    for _, fk in ipairs(sqlite_foreign_keys(table_name)) do
      if #fk.from == 1 then
        remember({
          from_table = table_name,
          to_table = fk.table,
          column = fk.from[1],
          primary_key = fk.to[1] or 'id',
          on_delete = fk.on_delete
        })
      end
    end
  end

  without_sqlite_foreign_keys('add_missing_foreign_keys', 'the SQLite tables', nil, function()
    local changed = true

    while changed do
      changed = false

      for _, fk in ipairs(foreign_keys) do
        if tables[fk.to_table] then
          local count, result = Statements.clean_orphans(fk.from_table, fk.to_table, fk)

          if result != 'kept' then
            summary[result] = summary[result] + count
            changed = true
          end
        end
      end
    end

    local to_create = {}
    local table_order = {}

    for _, fk in ipairs(missing) do
      local count = count_orphans(fk.from_table, fk.column, fk.to_table, fk.primary_key)

      if count > 0 then
        summary.skipped = summary.skipped + 1

        ErrorNoHalt('ActiveRecord - Not creating the foreign key from '..fk.from_table..'.'..fk.column
          ..' to '..fk.to_table..': '..count..' row(s) of '..fk.from_table..' refer to a row of '
          ..fk.to_table..' that does not exist, and its ON DELETE action ('
          ..normalize_on_delete(fk.on_delete)..') leaves them as they are. Delete those rows or '
          ..'set their '..fk.column..' to NULL and run add_missing_foreign_keys again.\n')
      else
        if !to_create[fk.from_table] then
          to_create[fk.from_table] = {}
          table_order[#table_order + 1] = fk.from_table
        end

        table.insert(to_create[fk.from_table], fk)
      end
    end

    for _, table_name in ipairs(table_order) do
      local list = to_create[table_name]
      local refusal = sqlite_rebuild_refusal(table_name)

      if refusal then
        summary.skipped = summary.skipped + #list

        ErrorNoHalt('ActiveRecord - Not creating the foreign keys of '..table_name..': the table cannot be '
          ..'rebuilt, '..refusal..'.\n')
      else
        local clauses = {}

        for index, fk in ipairs(list) do
          local on_delete = normalize_on_delete(fk.on_delete)

          clauses[index] = {
            from = { fk.column },
            table = fk.to_table,
            to = { fk.primary_key },
            on_delete = on_delete_clauses[on_delete] or on_delete:upper()
          }
        end

        rebuild_sqlite_table('add_missing_foreign_keys', table_name, { foreign_keys = clauses })

        for _, fk in ipairs(list) do
          print('ActiveRecord - Created the foreign key from '..table_name..'.'..fk.column
            ..' to '..fk.to_table..'.')
        end

        summary.created = summary.created + #list
      end
    end
  end)

  print('ActiveRecord - Foreign keys: '..summary.created..' created, '..summary.skipped..' left out; '
    ..summary.deleted..' row(s) deleted and '..summary.nullified..' set to NULL.')

  return summary
end

--- Makes the primary key of an SQLite table AUTOINCREMENT, so that the id of a deleted row is
-- never given to a new one; without it, SQLite gives the highest id of the table plus one,
-- which is the id of the last row again once that row has been deleted. The table is
-- rebuilt for it (see rebuild_sqlite_table), which keeps its rows and their ids. Does nothing
-- on other databases, whose primary keys never give an id out twice, and for a table that is
-- AUTOINCREMENT already, that has no primary key of the INTEGER type or that does not exist.
-- A table that cannot be rebuilt is left as it is, with a warning.
-- @param table_name [String]
-- @return [Boolean whether the table was rebuilt]
function Statements.add_autoincrement(table_name)
  local adapter = ActiveRecord.adapter

  if !adapter:is_sqlite() or !sqlite_table_sql(table_name) or sqlite_autoincrement(table_name) then
    return false
  end

  local columns = adapter:raw_query('PRAGMA table_info('..sql_quote_name(table_name)..');', rows)

  if !istable(columns) or !sqlite_integer_primary_key(columns) then
    return false
  end

  local refusal = sqlite_rebuild_refusal(table_name)

  if refusal then
    ErrorNoHalt('ActiveRecord - Not making the primary key of '..table_name
      ..' AUTOINCREMENT: the table cannot be rebuilt, '..refusal..'.\n')

    return false
  end

  rebuild_sqlite_table('add_autoincrement', table_name)

  return true
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
