--- Builds the column DSL of table definitions and converts values between Lua and the
-- database. `ActiveRecord.generate_create_funcs` gives a 'create' or 'change' query a
-- method for every column type of the adapter (`t:string 'name'`,
-- `t:integer { 'age', null = false }`) along with `t:timestamps` and `t:references`.
-- `ActiveRecord.str_to_type` and `ActiveRecord.type_to_db` convert the values of a column
-- when a model is loaded and saved, and `ActiveRecord.generate_tables` creates the tables
-- that ActiveRecord keeps its own bookkeeping in.

--- Splits the arguments of a column type method into the column name and its options.
-- @param name [String/Map column name, or a table holding the name at index 1 and the
--   options as keys]
-- @param ... [Vararg options table, when the name is given as a string]
-- @return [String column name, Map options]
function ActiveRecord.column_args(name, ...)
  local args = { ... }

  if istable(name) then
    args = table.Copy(name)
    name = args[1]
    table.remove(args, 1)
  elseif istable(args[1]) then
    args = args[1]
  end

  return name, args
end

--- Adds a column type method to a query, which lets columns be defined DSL-style.
-- The generated method takes the column name followed by its options, or a single
-- table holding both.
-- ```
-- ActiveRecord.generate_create_func(query, 'string', 'varchar(255)')
--
-- query:string 'name'
-- query:string('steam_id', { null = false })
-- query:string { 'steam_id', null = false }
-- ```
-- @param obj [ActiveRecord::Query query to add the method to]
-- @param type [String abstract column type, used as the name of the method]
-- @param def [String adapter-specific SQL type definition]
function ActiveRecord.generate_create_func(obj, type, def)
  obj[type] = function(s, name, ...)
    local args
    name, args = ActiveRecord.column_args(name, ...)

    s.def = def

    if s.handle_create_args then
      s:handle_create_args(args)
    end

    s:create(name, s.def)

    if ActiveRecord.ready then
      ActiveRecord.add_to_schema(obj.table_name, name, type, s.def, args)
    end

    ActiveRecord.adapter:create_column(s, name, args, obj, type, def)
  end
end

--- Adds a column type method for every type supported by the current adapter.
-- @param obj [ActiveRecord::Query query to add the methods to]
-- @see [ActiveRecord.generate_create_func]
function ActiveRecord.generate_create_funcs(obj)
  local tab = ActiveRecord.Adapters[ActiveRecord.adapter_name:capitalize()].types or {}

  for k, v in pairs(tab) do
    ActiveRecord.generate_create_func(obj, k, v)
  end

  --- Adds the 'created_at' and 'updated_at' datetime columns, NOT NULL unless told otherwise.
  -- @param args=nil [Map column options, e.g. { null = true }]
  obj.timestamps = function(s, args)
    args = args or {}

    local null = args.null

    if null == nil then null = false end

    s:datetime { 'created_at', null = null }
    s:datetime { 'updated_at', null = null }
  end

  --- Adds a '<name>_id' integer column that refers to the table named after the plural
  -- of the name, along with an index on it. A foreign key constraint is added as well
  -- if asked for. Both are created once the table statement has run.
  -- ```
  -- t:references 'user'
  -- t:references('user', { null = false, index = false })
  -- t:references { 'character', foreign_key = { on_delete = 'cascade' } }
  -- t:belongs_to('user', { foreign_key = true, to_table = 'players' })
  -- ```
  -- @param name [String/Map name of the referenced model, singular; or a table holding
  --   it at index 1 and the options as keys]
  -- @param ... [Vararg options table: column (defaults to '<name>_id'), to_table
  --   (defaults to the plural of the name), null, default, index (true by default) and
  --   foreign_key (true, or a table with on_delete, primary_key and name)]
  obj.references = function(s, name, ...)
    local args
    name, args = ActiveRecord.column_args(name, ...)

    local column = args.column or name..'_id'

    s:integer { column, null = args.null, default = args.default }

    s._references = s._references or {}

    table.insert(s._references, {
      column = column,
      to_table = args.to_table or Flow.Inflector:pluralize(name),
      index = args.index,
      foreign_key = args.foreign_key
    })
  end

  obj.belongs_to = obj.references
end

do
  local converters = {
    integer = tonumber,
    float = tonumber,
    boolean = tobool,
    decimal = tonumber,
    primary_key = tonumber
  }

  local reverse_converters = {
    boolean = function(val)
      if tobool(val) == false then
        return 0
      end

      return 1
    end
  }

  --- Converts a raw database value to the Lua type matching an abstract column type.
  -- @param str [Any value as returned by the database, usually a string]
  -- @param type [String abstract column type]
  -- @return [Number/Boolean/Any number for 'integer', 'float', 'decimal' and 'primary_key'
  --   columns, boolean for 'boolean' columns, the unchanged value for anything else]
  function ActiveRecord.str_to_type(str, type)
    local conv = converters[type]

    if conv then
      return conv(str)
    end

    return str
  end

  --- Converts a Lua value to the form in which it is written to the database.
  -- @param val [Any]
  -- @param type [String abstract column type]
  -- @return [Number/String 0 or 1 for 'boolean' columns, otherwise the value converted
  --   to a string; nil if the value is nil]
  function ActiveRecord.type_to_db(val, type)
    if val == nil then return end

    local conv = reverse_converters[type]

    if conv then
      return conv(val)
    end

    return tostring(val)
  end
end

--- Returns the name of the database table for a model class name, which is its
-- underscored plural ('TempPermission' becomes 'temp_permissions').
-- @param class_name [String]
-- @return [String]
function ActiveRecord.generate_table_name(class_name)
  return Flow.Inflector:pluralize(class_name:underscore())
end

--- Creates the internal tables if they do not exist yet: 'ar_schema' (the columns of
-- every table), 'ar_metadata' (key-value storage, which also holds the indexes and
-- foreign keys) and 'ar_schema_migrations' (the migrations that have been run).
function ActiveRecord.generate_tables()
  ActiveRecord.SchemaStatements.create_table('ar_schema', { if_not_exists = true }, function(t)
    t:string 'table_name'
    t:string 'column_name'
    t:string 'abstract_type'
    t:string 'definition'
  end)

  ActiveRecord.SchemaStatements.create_table('ar_metadata', { if_not_exists = true }, function(t)
    t:string 'key'
    t:text 'value'
  end)

  ActiveRecord.SchemaMigration:create_table()
end
