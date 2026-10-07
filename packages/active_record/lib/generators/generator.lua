--- Adds a column type method to a query, which lets columns be defined DSL-style.
-- The generated method takes the column name followed by its options, or a single
-- table holding both.
-- ```
-- ActiveRecord.generate_create_func(query, 'string', 'varchar(255)')
--
-- query:string 'name'
-- query:string { 'steam_id', null = false }
-- ```
-- @param obj [ActiveRecord::Query query to add the method to]
-- @param type [String abstract column type, used as the name of the method]
-- @param def [String adapter-specific SQL type definition]
function ActiveRecord.generate_create_func(obj, type, def)
  obj[type] = function(s, name, ...)
    local args = { ... }
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
    if ActiveRecord.ready then
      ActiveRecord.add_to_schema(obj.table_name, name, type)
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

--- Creates the internal 'ar_schema' and 'ar_metadata' tables if they do not exist yet.
function ActiveRecord.generate_tables()
  create_table('ar_schema', function(t)
    t:overwrite(false)

    t:primary_key 'id'
    t:string 'table_name'
    t:string 'column_name'
    t:string 'abstract_type'
    t:string 'definition'
  end)

  create_table('ar_metadata', function(t)
    t:overwrite(false)

    t:primary_key 'id'
    t:string 'key'
    t:string 'value'
  end)
end
