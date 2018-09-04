include 'infector.lua'
include 'pluralize.lua'

function ActiveRecord.generate_create_func(obj, type, def)
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
    if ActiveRecord.ready then
      ActiveRecord.add_to_schema(obj.table_name, name, type)
    end
    ActiveRecord.adapter:create_column(s, name, args, obj, type, def)
  end
end

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

  function ActiveRecord.str_to_type(str, type)
    local conv = converters[type]
  
    if conv then
      return conv(str)
    end

    return str
  end
end

function ActiveRecord.generate_table_name(class_name)
  return ActiveRecord.Infector:pluralize(class_name:to_snake_case())
end

function ActiveRecord.generate_tables()
  create_table('activerecord_schema', function(t)
    t:primary_key 'id'
    t:string 'table_name'
    t:string 'column_name'
    t:string 'abstract_type'
    t:string 'definition'
  end)
end
