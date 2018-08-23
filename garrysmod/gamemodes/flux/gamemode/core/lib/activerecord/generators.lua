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
    ActiveRecord.add_to_schema(obj.table_name, name, type)
    if k == 'primary_key' then
      s:set_primary_key(name)
    end
  end
end

function ActiveRecord.generate_create_funcs(obj)
  local tab = ActiveRecord.Adapters[ActiveRecord.adapter_name:capitalize()].types or {}

  for k, v in pairs(tab) do
    generate_create_func(obj, k, v)
  end
end

do
  local vowels = {
    ['a'] = true, ['e'] = true,
    ['o'] = true, ['i'] = true,
    ['u'] = true
  }

  function ActiveRecord.pluralize(str)
    local len = str:len()
    local last_char = str[len]:lower()
    local prev_char = str[len - 1]:lower()

    if vowels[last_char] then
      if last_char == 'y' then
        return str:sub(1, len - 1)..'ies'
      elseif last_char == 'e' then
        return str..'s'
      else
        return str..'es'
      end
    else
      if last_char == 's' then
        if prev_char == 'u' then
          return str:sub(1, len - 2)..'i'
        else
          return str..'es'
        end
      else
        return str..'s'
      end
    end
  end
end

function ActiveRecord.generate_table_name(class_name)
  return ActiveRecord.pluralize(class_name:to_snake_case())
end

function ActiveRecord.generate_tables()
  create_table('activerecord_schema', function(t)
    t:primary_key 'id'
    t:string 'name'
    t:string 'abstract_type'
    t:string 'definition'
  end)
end
