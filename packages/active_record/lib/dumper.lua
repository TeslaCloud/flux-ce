--- Generates the schema file. `ActiveRecord.dump_schema` turns the schema that
-- ActiveRecord keeps in memory (tables and their columns, indexes, foreign keys and
-- primary keys) into the Lua source of `db/schema.lua`: a single
-- `ActiveRecord::Schema#define` call made of the schema statements that recreate the
-- database. `ActiveRecord.Tasks.schema_dump` writes it to disk, which also happens after
-- migrations have been run.

local function lua_literal(value)
  if isstring(value) then
    return string.format('%q', value)
  end

  return tostring(value)
end

local function quote(str)
  return "'"..tostring(str).."'"
end

local function column_list(columns)
  local quoted = {}

  for k, v in ipairs(columns) do
    table.insert(quoted, quote(v))
  end

  return '{ '..table.concat(quoted, ', ')..' }'
end

local function options_literal(options, order)
  local parts = {}

  for k, key in ipairs(order) do
    local value = options[key]

    if value != nil then
      table.insert(parts, key..' = '..(isstring(value) and quote(value) or tostring(value)))
    end
  end

  if #parts == 0 then return end

  return '{ '..table.concat(parts, ', ')..' }'
end

--- Generates the Lua source of the schema file ('db/schema.lua') from the schema and
-- its metadata (indexes, foreign keys and primary keys), in the shape of the schema
-- statements that create it. The internal 'ar_*' tables are left out.
-- @param version [Number/String schema version to write into the file]
-- @return [String Lua source code]
function ActiveRecord.dump_schema(version)
  local lines = {
    '-- This file is auto-generated from the current state of the database. Instead',
    '-- of editing this file, please use the migrations feature of Active Record to',
    '-- incrementally modify your database, and then regenerate this schema definition.',
    '--',
    '-- This file is the source Active Record uses to define your schema when running',
    '-- `flux db:schema:load`, or when the server starts with an empty database. When',
    '-- creating a new database, loading the schema tends to be faster and is less error',
    '-- prone than running all of your migrations from scratch. Old migrations may fail',
    '-- to apply correctly if those migrations use external dependencies or application',
    '-- code.',
    '--',
    "-- It's strongly recommended that you check this file into your version control system.",
    '--',
    '-- Dumped at '..to_datetime(os.time()),
    'ActiveRecord.Schema:define({ version = '..string.format('%.0f', tonumber(version) or 0)..' }, function()'
  }

  local metadata = ActiveRecord.metadata or {}
  local tables = {}

  for table_name, structure in SortedPairs(ActiveRecord.schema or {}) do
    if istable(structure) and !table_name:start_with('ar_') then
      table.insert(tables, table_name)
    end
  end

  for k, table_name in ipairs(tables) do
    local structure = ActiveRecord.schema[table_name]
    local columns = {}
    local primary_key = nil

    for column, data in pairs(structure) do
      if isstring(column) and istable(data) then
        if data.type == 'primary_key' and !primary_key then
          primary_key = column
        else
          table.insert(columns, {
            name = column,
            id = tonumber(data.id) or 0,
            type = data.type,
            null = data.null,
            default = data.default
          })
        end
      end
    end

    table.sort(columns, function(a, b)
      if a.id == b.id then return a.name < b.name end

      return a.id < b.id
    end)

    local options = { 'force = true' }

    if !primary_key then
      table.insert(options, 'id = false')
    elseif primary_key != 'id' then
      table.insert(options, 'primary_key = '..quote(primary_key))
    end

    table.insert(lines, '  create_table('..quote(table_name)..', { '..table.concat(options, ', ')..' }, function(t)')

    for k2, column in ipairs(columns) do
      local column_options = {}

      if column.null != nil then
        table.insert(column_options, 'null = '..tostring(column.null))
      end

      if column.default != nil then
        table.insert(column_options, 'default = '..lua_literal(column.default))
      end

      if #column_options > 0 then
        table.insert(
          lines,
          '    t:'..column.type..' { '..quote(column.name)..', '..table.concat(column_options, ', ')..' }'
        )
      else
        table.insert(lines, '    t:'..column.type..' '..quote(column.name))
      end
    end

    table.insert(lines, '  end)')

    if k < #tables then
      table.insert(lines, '')
    end
  end

  local indexes = {}

  for name, index in SortedPairs(metadata.indexes or {}) do
    if istable(index) and index.table and !index.table:start_with('ar_') then
      table.insert(indexes, '  add_index('..quote(index.table)..', '..column_list(index.columns or {})..', '
        ..(options_literal({
          name = name,
          unique = index.unique,
          length = index.length,
          using = index.using,
          where = index.where
        }, { 'name', 'unique', 'length', 'using', 'where' }) or '{}')..')')
    end
  end

  if #indexes > 0 then
    table.insert(lines, '')
    table.Add(lines, indexes)
  end

  local foreign_keys = {}

  for name, fk in SortedPairs(metadata.references or {}) do
    if istable(fk) and fk.from_table and fk.to_table then
      table.insert(foreign_keys, '  add_foreign_key('..quote(fk.from_table)..', '..quote(fk.to_table)..', '
        ..(options_literal({
          column = fk.column,
          primary_key = fk.primary_key,
          on_delete = fk.on_delete,
          name = name
        }, { 'column', 'primary_key', 'on_delete', 'name' }) or '{}')..')')
    end
  end

  if #foreign_keys > 0 then
    table.insert(lines, '')
    table.Add(lines, foreign_keys)
  end

  local primary_keys = {}

  for name, pk in SortedPairs(metadata.prim_keys or {}) do
    if istable(pk) and pk.table then
      table.insert(primary_keys, '  create_primary_key('..quote(pk.table)..', '..quote(pk.column)..')')
    end
  end

  if #primary_keys > 0 then
    table.insert(lines, '')
    table.Add(lines, primary_keys)
  end

  table.insert(lines, 'end)')

  return table.concat(lines, '\n')..'\n'
end
